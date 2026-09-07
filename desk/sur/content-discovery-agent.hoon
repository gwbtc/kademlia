::  Topic-discovery peer protocol, operations, and persistent state.
::
/-  *kademlia, *kademlia-agent, *content-routing, *content-discovery, *bounded-poke
|%
+$  discovery-version  @tas
+$  operation-id  @uv
+$  discovery-request-id  @uv
+$  operation-callback  [recipient=@tas reply-path=path]
+$  discovery-config
  $:  replication=@ud
      concurrency=@ud
      global-concurrency=@ud
      request-timeout=@dr
      lease=@dr
      refresh=@dr
      refresh-batch=@ud
      max-record-bytes=@ud
      max-records-per-key=@ud
      max-records-per-publisher=@ud
      max-replica-keys=@ud
  ==
+$  record  discovery-record
+$  records  discovery-records
+$  sized-record  [value=record bytes=@ud]
+$  sized-records  (list sized-record)
+$  reject-reason
  ?(%invalid %expired %too-large %stale %conflict %publisher-cap %capacity)
+$  store-status
  $%  [%accepted ~]
      [%rejected reason=reject-reason]
  ==
+$  discovery-message
  $%  [%store version=discovery-version id=discovery-request-id payload=@]
      [%stored version=discovery-version id=discovery-request-id status=store-status]
      [%find-topic version=discovery-version id=discovery-request-id topic=topic-path]
      [%topic-records version=discovery-version id=discovery-request-id count=@ud payload=@]
  ==
+$  publication-result
  $:  identity=record-identity
      key=key
      accepted=(set node-id)
      rejected=(map node-id reject-reason)
      timed-out=(set node-id)
  ==
+$  browse-result
  $:  topic=topic-path
      selection=topic-selection
      responders=(set node-id)
      timed-out=(set node-id)
  ==
+$  operation-result
  $%  [%published value=publication-result]
      [%topic value=browse-result]
  ==
+$  advertisement-result
  [records=(list publication-result)]
+$  discovery-result
  $%  [%advertised value=advertisement-result]
      [%topic value=browse-result]
  ==
+$  discovery-view
  $%  [%running ~]
      [%complete value=discovery-result]
  ==
+$  operation-notice  [reply-path=path result=discovery-result]
+$  discovery-command
  $%  [%reset ~]
      $:  %advertise
          id=operation-id
          topic=topic-path
          format=@tas
          catalog=digest
          entries=@ud
          revision=@ud
          expires=@da
      ==
      [%browse id=operation-id topic=topic-path]
      [%observe id=operation-id recipient=@tas reply-path=path]
      [%forget id=operation-id]
      [%set-config value=discovery-config]
      [%set-verbosity level=verbosity]
  ==
+$  leased-record  [value=record lease-until=@da]
+$  leased-records  (list leased-record)
+$  operation-kind
  $%  [%publish value=record key=key payload=@]
      [%browse topic=topic-path key=key]
  ==
+$  operation
  $:  kind=operation-kind
      phase=?
      remaining=(list node-id)
      in-flight=@ud
      accepted=(set node-id)
      rejected=(map node-id reject-reason)
      timed-out=(set node-id)
      responders=(set node-id)
      admitted=(set record)
      records=records
  ==
+$  operation-completion  [id=operation-id result=operation-result]
+$  operation-view
  $%  [%running value=operation]
      [%complete value=operation-result]
  ==
+$  pending-discovery-request
  $:  operation=operation-id
      peer=node-id
      kind=?
      deadline=@da
      delivery=delivery-id
  ==
+$  advertise-batch
  $:  tasks=(set operation-id)
      results=(list publication-result)
  ==
+$  discovery-state
  $:  config=discovery-config
      replicas=(map key leased-records)
      replica-count=@ud
      origins=(map [key record-identity] record)
      active=(map operation-id operation)
      completed=(map operation-id operation-result)
      pending=(map discovery-request-id pending-discovery-request)
      pending-count=@ud
      next-request=discovery-request-id
      refresh-at=@da
      next-operation=operation-id
      background=(set operation-id)
      callbacks=(map operation-id operation-callback)
      ready=(qeu operation-id)
      queued=(set operation-id)
      refresh-queue=(list [key record-identity])
      batches=(map operation-id advertise-batch)
      task-owner=(map operation-id operation-id)
      completed-public=(map operation-id discovery-result)
      outbound=delivery-state
  ==
+$  operation-update
  [completions=(list operation-completion) state=discovery-state]
+$  discovery-saved-state
  [state=discovery-state verbosity=verbosity]
--
