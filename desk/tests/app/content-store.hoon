/-  *kademlia, *content-routing, cra=content-routing-agent
/-  cd=content-discovery, cda=content-discovery-agent, *content-store
/+  cr=content-routing, *test
/=  agent  /app/content-store
|%
++  now  ~2026.9.14..12.00.00
::
++  bowl
  ^-  bowl:gall
  %*  .  *bowl:gall
    our  ~zod
    src  ~zod
    dap  %content-store
    now  now
  ==
::
++  get-state
  |=  saved=vase
  ^-  content-store-state
  =/  app=content-store-saved-state
    !<(content-store-saved-state saved)
  state.app
::
++  accepted-publication
  |=  key=key
  ^-  publication-result:cra
  =/  accepted=(set node-id)
    (~(put in *(set node-id)) 0x1)
  [key accepted ~ ~]
::
++  get-value
  |=  result=content-store-result
  ^-  (cask)
  ?>  ?=(%get -.result)
  value.value.result
::
++  test-init-settings-and-load
  =/  initialized  on-init:~(. agent bowl)
  =/  saved=content-store-saved-state
    !<(content-store-saved-state on-save:+.initialized)
  =/  peek=(unit (unit cage))  (on-peek:+.initialized /x/settings)
  =/  settings=content-store-config
    !<(content-store-config q:(need (need peek)))
  =/  loaded  (on-load:~(. agent bowl) !>(saved))
  =/  restored=content-store-saved-state
    !<(content-store-saved-state on-save:+.loaded)
  ;:  weld
    %+  expect-eq  !>(`content-store-config`[~s30 ~d1 8.388.608])
    !>(settings)
    %+  expect-eq  !>(state.saved)
    !>(state.restored)
  ==
::
++  test-put-completes-and-local-get-returns-content
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  content=digest  (digest-cask:cr value)
  =/  put=content-store-command  [%put 0v1 value [~ ~] ~]
  =/  started
    (on-poke:+.initialized %content-store-command !>(put))
  =/  started-state=content-store-state  (get-state on-save:+.started)
  =/  publication=publication-result:cra
    (accepted-publication (provider-key:cr content))
  =/  notice=operation-notice:cra
    [/put/provider/0v1/0v1 [%published publication]]
  =/  published
    (on-poke:+.started %content-routing-result !>(notice))
  =/  published-state=content-store-state  (get-state on-save:+.published)
  =/  result=content-store-result
    (need (~(get by completed.published-state) 0v1))
  =/  got
    %+  on-poke:+.published  %content-store-command
    !>(`content-store-command`[%get 0v2 [%content content]])
  =/  got-state=content-store-state  (get-state on-save:+.got)
  =/  get-result=content-store-result
    (need (~(get by completed.got-state) 0v2))
  ;:  weld
    %+  expect-eq  !>(5)
    !>((lent -.started))
    %+  expect-eq  !>(1)
    !>((lent ~(tap by pages.started-state)))
    %+  expect-eq  !>(1)
    !>((need (~(get by provider-revisions.started-state) content)))
    (expect !>(?=(%put -.result)))
    (expect !>(?=(%get -.get-result)))
    %+  expect-eq  !>(value)
    !>((get-value get-result))
  ==
::
++  test-repeat-put-reuses-page-and-increments-provider-revision
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  content=digest  (digest-cask:cr value)
  =/  first
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%put 0v1 value [~ ~] ~])
  =/  first-publication=publication-result:cra
    (accepted-publication (provider-key:cr content))
  =/  first-notice=operation-notice:cra
    [/put/provider/0v1/0v1 [%published first-publication]]
  =/  completed
    (on-poke:+.first %content-routing-result !>(first-notice))
  =/  second
    %+  on-poke:+.completed  %content-store-command
    !>(`content-store-command`[%put 0v2 value [~ ~] ~])
  =/  state=content-store-state  (get-state on-save:+.second)
  ;:  weld
    %+  expect-eq  !>(4)
    !>((lent -.second))
    %+  expect-eq  !>(1)
    !>((lent ~(tap by pages.state)))
    %+  expect-eq  !>(2)
    !>((need (~(get by provider-revisions.state) content)))
  ==
::
++  test-search-completes-through-discovery-callback
  =/  initialized  on-init:~(. agent bowl)
  =/  topic=topic-path:cd  ~[%software]
  =/  started
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%search 0v4 topic])
  =/  browse=browse-result:cda  [topic [~ ~ ~] ~ ~]
  =/  notice=operation-notice:cda
    [/search/0v4/0v1 [%topic browse]]
  =/  finished
    (on-poke:+.started %content-discovery-result !>(notice))
  =/  state=content-store-state  (get-state on-save:+.finished)
  =/  result=content-store-result
    (need (~(get by completed.state) 0v4))
  ;:  weld
    %+  expect-eq  !>(4)
    !>((lent -.started))
    (expect !>(?=(%search -.result)))
  ==
::
++  test-observer-receives-immediate-local-get
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  content=digest  (digest-cask:cr value)
  =/  state=content-store-state  (get-state on-save:+.initialized)
  =.  values.state  (~(put by values.state) content value)
  =/  loaded
    (on-load:~(. agent bowl) !>(`content-store-saved-state`[state %off]))
  =/  observed
    %+  on-poke:+.loaded  %content-store-command
    !>(`content-store-command`[%observe 0v9 %sink /reply])
  =/  finished
    %+  on-poke:+.observed  %content-store-command
    !>(`content-store-command`[%get 0v9 [%content content]])
  =/  final=content-store-state  (get-state on-save:+.finished)
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent -.finished))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by callbacks.final)))
  ==
::
++  test-size-limit-produces-retained-failure
  =/  initialized  on-init:~(. agent bowl)
  =/  configured
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%set-config [~s1 ~d1 1]])
  =/  failed
    %+  on-poke:+.configured  %content-store-command
    !>(`content-store-command`[%put 0v10 [%noun 42] [~ ~] ~])
  =/  state=content-store-state  (get-state on-save:+.failed)
  =/  result=content-store-result
    (need (~(get by completed.state) 0v10))
  %+  expect-eq  !>(`content-store-result`[%failed %too-large])
  !>(result)
::
++  test-zero-publication-lifetime-is-invalid
  =/  initialized  on-init:~(. agent bowl)
  =/  failed
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%put 0v11 [%noun 42] [~ ~] `~s0])
  =/  state=content-store-state  (get-state on-save:+.failed)
  =/  result=content-store-result
    (need (~(get by completed.state) 0v11))
  %+  expect-eq  !>(`content-store-result`[%failed %invalid])
  !>(result)
::
++  test-invalid-mutable-name-is-rejected
  =/  initialized  on-init:~(. agent bowl)
  =/  invalid=publication-options
    [`[namespace=%demo name=~ revision=1] ~]
  =/  put
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%put 0v12 [%noun 42] invalid ~])
  =/  put-state=content-store-state  (get-state on-save:+.put)
  =/  put-result=content-store-result
    (need (~(get by completed.put-state) 0v12))
  =/  get
    %+  on-poke:+.put  %content-store-command
    !>(`content-store-command`[%get 0v13 [%name ~zod %demo ~]])
  =/  get-state=content-store-state  (get-state on-save:+.get)
  =/  get-result=content-store-result
    (need (~(get by completed.get-state) 0v13))
  ;:  weld
    %+  expect-eq  !>(`content-store-result`[%failed %invalid])
    !>(put-result)
    %+  expect-eq  !>(`content-store-result`[%failed %invalid])
    !>(get-result)
  ==
--
