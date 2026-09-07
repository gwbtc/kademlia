::  Content-record transport protocol and persistent-state molds.
::
/-  *kademlia, *kademlia-agent, *content-routing, *bounded-poke
|%
+$  content-version  @tas
+$  operation-id     @uv
+$  content-request-id  @uv
+$  operation-callback  [recipient=@tas reply-path=path]
+$  operation-notice  [reply-path=path result=operation-result]
+$  content-config
  $:  replication=@ud
      concurrency=@ud
      global-concurrency=@ud
      request-timeout=@dr
      lease=@dr
      refresh=@dr
      refresh-batch=@ud
      max-record-bytes=@ud
      max-providers=@ud
      max-replica-keys=@ud
  ==
+$  record
  $%  [%pointer value=pointer]
      [%provider value=provider]
  ==
+$  records  (list record)
::  A decoded record paired with its already-validated encoded byte size.
+$  sized-record  [value=record bytes=@ud]
+$  sized-records  (list sized-record)
+$  query
  $%  [%pointer key=key]
      [%providers content=digest]
  ==
+$  reject-reason
  ?(%invalid %unknown-key %expired %too-large %stale %conflict-cap %provider-cap %capacity)
+$  store-status
  $%  [%accepted ~]
      [%rejected reason=reject-reason]
  ==
+$  content-message
  $%  [%store version=content-version id=content-request-id payload=@]
      [%stored version=content-version id=content-request-id status=store-status]
      [%find-records version=content-version id=content-request-id request=query]
      [%records version=content-version id=content-request-id count=@ud payload=@]
  ==
+$  content-command
  $%  [%reset ~]
      $:  %publish-pointer
          id=operation-id
          namespace=@tas
          name=*
          revision=@ud
          expires=(unit @da)
          target=target
      ==
      $:  %publish-provider
          id=operation-id
          content=digest
          revision=@ud
          expires=@da
          locations=locators
      ==
      [%find-pointer id=operation-id namespace=@tas publisher=node-id name=*]
      [%find-providers id=operation-id content=digest]
      [%observe id=operation-id recipient=@tas reply-path=path]
      [%forget id=operation-id]
      [%set-config value=content-config]
      [%set-verbosity level=verbosity]
  ==
+$  leased-record
  [value=record lease-until=@da]
+$  leased-records  (list leased-record)
+$  publication-result
  $:  key=key
      accepted=(set node-id)
      rejected=(map node-id reject-reason)
      timed-out=(set node-id)
  ==
+$  pointer-result
  $:  selection=pointer-selection
      responders=(set node-id)
      timed-out=(set node-id)
  ==
+$  providers-result
  $:  selection=provider-selection
      responders=(set node-id)
      timed-out=(set node-id)
  ==
+$  operation-result
  $%  [%published value=publication-result]
      [%pointer value=pointer-result]
      [%providers value=providers-result]
  ==
+$  operation-completion
  [id=operation-id result=operation-result]
+$  operation-kind
  $%  [%publish value=record key=key payload=@]
      [%find-pointer namespace=@tas publisher=node-id key=key]
      [%find-providers content=digest key=key]
  ==
+$  operation
  $:  kind=operation-kind
      phase=?                                      :: %.n lookup, %.y requests
      remaining=(list node-id)
      in-flight=@ud
      accepted=(set node-id)
      rejected=(map node-id reject-reason)
      timed-out=(set node-id)
      responders=(set node-id)
      admitted=(set record)                         :: authenticated exact records
      pointers=pointers
      providers=providers
  ==
+$  operation-view
  $%  [%running value=operation]
      [%complete value=operation-result]
  ==
+$  pending-content-request
  $:  operation=operation-id
      peer=node-id
      kind=?                                      :: %.n store, %.y query
      deadline=@da
      delivery=delivery-id
  ==
+$  content-state
  $:  config=content-config
      replicas=(map key leased-records)
      replica-count=@ud
      origins=(map key record)
      active=(map operation-id operation)
      completed=(map operation-id operation-result)
      pending=(map content-request-id pending-content-request)
      pending-count=@ud
      next-request=content-request-id
      refresh-at=@da
      next-operation=operation-id
      background=(set operation-id)
      callbacks=(map operation-id operation-callback)
      ready=(qeu operation-id)
      queued=(set operation-id)
      refresh-queue=(list key)
      outbound=delivery-state
  ==
+$  operation-update
  [completions=(list operation-completion) state=content-state]
+$  content-saved-state
  [state=content-state verbosity=verbosity]
--
