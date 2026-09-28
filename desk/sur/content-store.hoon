::  Unified content publication, retrieval, and topic-search molds.
::
/-  *kademlia, *content-routing
/-  cd=content-discovery, cra=content-routing-agent, cda=content-discovery-agent
|%
+$  content-store-id  @uv
+$  content-store-verbosity  ?(%off %info %debug)
+$  content-store-config
  $:  request-timeout=@dr
      publication-lifetime=@dr
      max-content-bytes=@ud
  ==
+$  name-key
  [namespace=@tas name=path]
+$  name-revision-policy
  $%  [%auto ~]
      [%set value=@ud]
      [%cas expected=@ud value=@ud]
  ==
+$  named-publication
  $:  namespace=@tas
      name=path
      revision=name-revision-policy
  ==
+$  topic-publication
  $:  topic=topic-path:cd
      format=@tas
      entries=@ud
      revision=@ud
  ==
+$  publication-options
  [name=(unit named-publication) topic=(unit topic-publication)]
+$  content-store-query
  $%  [%content digest=digest]
      [%name publisher=@p namespace=@tas name=path]
  ==
+$  content-store-command
  $%  $:  %put
          id=content-store-id
          value=(cask)
          options=publication-options
          lifetime=(unit @dr)
      ==
      [%get id=content-store-id query=content-store-query]
      [%search id=content-store-id topic=topic-path:cd]
      [%observe id=content-store-id recipient=@tas reply-path=path]
      [%forget id=content-store-id]
      [%set-config value=content-store-config]
      [%set-verbosity level=content-store-verbosity]
  ==
+$  content-store-failure
  ?(%invalid %too-large %revision-conflict %pointer-not-found %pointer-conflict %unverifiable-direct %provider-not-found %unsupported-locator %remote-scry-empty %remote-scry-too-large %digest-mismatch %request-timeout %provider-publication-failed %pointer-publication-failed %topic-publication-failed %dependency-failed)
+$  put-result
  $:  content=digest
      locator=locator
      provider=publication-result:cra
      pointer=(unit publication-result:cra)
      pointer-revision=(unit @ud)
      topic=(unit advertisement-result:cda)
  ==
+$  get-result
  $:  content=digest
      value=(cask)
      source=(unit locator)
  ==
+$  search-result
  [value=browse-result:cda]
+$  content-store-result
  $%  [%put value=put-result]
      [%get value=get-result]
      [%search value=search-result]
      [%failed reason=content-store-failure]
  ==
+$  content-store-callback
  [recipient=@tas reply-path=path]
+$  content-store-notice
  [reply-path=path result=content-store-result]
+$  published-page
  [spur=path locator=locator]
::
::  Internal operation phases.  Lower-layer operation IDs are encoded in
::  callback paths, so no separate correlation map is required.
+$  put-operation
  $:  content=digest
      locator=locator
      provider-done=?
      provider=(unit publication-result:cra)
      pointer-done=?
      pointer=(unit publication-result:cra)
      pointer-revision=(unit @ud)
      topic-done=?
      topic=(unit advertisement-result:cda)
      failure=(unit content-store-failure)
  ==
+$  content-store-operation
  $%  [%put value=put-operation]
      [%pointer query=content-store-query]
      [%providers content=digest]
      [%scry content=digest source=locator deadline=@da]
      [%search topic=topic-path:cd]
  ==
+$  content-store-view
  $%  [%running value=content-store-operation]
      [%complete value=content-store-result]
  ==
+$  content-store-state
  $:  config=content-store-config
      values=(map digest (cask))
      pages=(map digest published-page)
      provider-revisions=(map digest @ud)
      pointer-revisions=(map name-key @ud)
      active=(map content-store-id content-store-operation)
      completed=(map content-store-id content-store-result)
      callbacks=(map content-store-id content-store-callback)
      next-content=@uv
      next-discovery=@uv
  ==
+$  content-store-saved-state
  [state=content-store-state verbosity=content-store-verbosity]
--
