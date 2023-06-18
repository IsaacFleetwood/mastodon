# frozen_string_literal: true

class ActivityPub::ForcePullStatusesService < BaseService
  include JsonLdHelper

  def call(account, **options)
    return if account.outbox_url.blank? || account.suspended? || account.local?

    @account = account
    @options = options
    @json    = fetch_resource(@account.outbox_url, true, local_follower)

    return unless supported_context?(@json)

    process_note_items(collection_items(@json))
  end

  private

  def collection_items(collection)
    collection = fetch_collection(collection['first']) if collection['first'].present?
    return unless collection.is_a?(Hash)

    case collection['type']
    when 'Collection', 'CollectionPage'
      collection['items']
    when 'OrderedCollection', 'OrderedCollectionPage'
      collection['orderedItems']
    end
  end

  def fetch_collection(collection_or_uri)
    return collection_or_uri if collection_or_uri.is_a?(Hash)
    return if non_matching_uri_hosts?(@account.uri, collection_or_uri)

    fetch_resource_without_id_validation(collection_or_uri, local_follower, true)
  end

  def process_note_items(items)
    status_ids = items.filter_map do |item|
      next unless item.is_a?(String) || item['type'] == 'Note'

      uri = value_or_id(item)
      next if ActivityPub::TagManager.instance.local_uri?(uri) || non_matching_uri_hosts?(@account.uri, uri)

      status = ActivityPub::FetchRemoteStatusService.new.call(uri, on_behalf_of: local_follower, expected_actor_uri: @account.uri, request_id: @options[:request_id])
      next unless status&.account_id == @account.id

      status.id
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.debug { "Invalid pinned status #{uri}: #{e.message}" }
      nil
    end
  end

  def local_follower
    return @local_follower if defined?(@local_follower)

    @local_follower = @account.followers.local.without_suspended.first
  end
end
