::  Demo resource, browser command, transfer, and profiling molds.
::
/-  *kademlia, *kademlia-agent, *content-routing
|%
+$  run-id  @tas
+$  demo-version  @tas
+$  transfer-id  @uv
+$  transport  ?(%custom %scry)
+$  resource-payload  [mime=@t size=@ud data=@]
+$  demo-config
  $:  chunk-bytes=@ud
      window=@ud
      request-timeout=@dr
      max-resource-bytes=@ud
      max-active=@ud
  ==
+$  resource
  $:  seed=@
      size=@ud
      mime=@t
      fill=@ud
      content=digest
  ==
+$  resources  (map digest resource)
+$  fetch-query
  $%  [%content digest=digest]
      [%name publisher=@p namespace=@tas name=@t]
  ==
+$  demo-command
  $%  [%reset ~]
      [%create run=run-id seed=@ size=@ud mime=@t]
      $:  %publish
          run=run-id
          content=digest
          transport=transport
          name=(unit [namespace=@tas name=@t revision=@ud])
      ==
      [%lookup run=run-id target=@p]
      [%fetch run=run-id query=fetch-query]
      $:  %advertise-topic
          run=run-id
          content=digest
          topic=(list @tas)
          format=@tas
          revision=@ud
      ==
      [%browse-topic run=run-id topic=(list @tas)]
      [%cancel run=run-id]
      $:  %network
          seeds=(list @p)
          request-timeout=@dr
          refresh-interval=@dr
          verbosity=verbosity
      ==
  ==
+$  transfer-message
  $%  $:  %chunk-request
          version=demo-version
          id=transfer-id
          content=digest
          offset=@ud
          length=@ud
      ==
      $:  %chunk
          version=demo-version
          id=transfer-id
          content=digest
          offset=@ud
          total=@ud
          mime=@t
          length=@ud
          payload=@
      ==
      $:  %unavailable
          version=demo-version
          id=transfer-id
          content=digest
          reason=?(%missing %invalid %too-large %busy)
      ==
  ==
+$  phase
  ?(%started %lookup-started %lookup-complete %pointer-started %pointer-complete %providers-started %providers-complete %topic-advertise-started %topic-advertise-complete %topic-browse-started %topic-browse-complete %transfer-started %first-byte %transfer-progress %transfer-complete %verify-complete %complete %cancelled %failed)
+$  pending-chunk
  $:  run=run-id
      provider=node-id
      offset=@ud
      length=@ud
      deadline=@da
      retries=@ud
  ==
+$  fetch-state
  $:  run=run-id
      query=fetch-query
      content=(unit digest)
      providers=(list node-id)
      provider=(unit node-id)
      total=(unit @ud)
      mime=(unit @t)
      data=@
      received=(set @ud)
      received-bytes=@ud
      next-offset=@ud
      in-flight=@ud
      first-byte=?
  ==
+$  publication-state
  $:  content=digest
      name=(unit [namespace=@tas name=@t revision=@ud])
      provider-done=?
      pointer-done=?
      failed=?
  ==
+$  operation-kind
  $%  [%lookup target=@p]
      [%publish state=publication-state]
      [%fetch state=fetch-state]
      [%advertise-topic content=digest topic=(list @tas)]
      [%browse-topic topic=(list @tas)]
  ==
+$  operation
  [kind=operation-kind started=@da]
+$  demo-state-v1
  $:  config=demo-config
      resources=resources
      active=(map run-id operation)
      requests=(map transfer-id pending-chunk)
      next-request=transfer-id
      next-content-operation=@uv
      next-lookup=@uv
      wake=(unit @da)
  ==
+$  demo-state
  $:  config=demo-config
      resources=resources
      active=(map run-id operation)
      requests=(map transfer-id pending-chunk)
      next-request=transfer-id
      next-content-operation=@uv
      next-lookup=@uv
      wake=(unit @da)
      scry-spurs=(set path)
  ==
--
