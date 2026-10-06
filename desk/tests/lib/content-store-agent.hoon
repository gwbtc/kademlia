/-  *kademlia, *content-routing, cra=content-routing-agent
/-  cd=content-discovery, cda=content-discovery-agent, *content-store
/+  cr=content-routing, *test, default-agent
/+  content-store-agent
|%
++  agent  (agent:content-store-agent stub)
::
::  stub: wrapped agent.  it saves the marks it was poked with, swallows
::  commands for the layers below, and emits the cards poked at it as
::  %test-cards.
::
++  stub
  =|  got=(list mark)
  ^-  agent:gall
  |_  =bowl:gall
  +*  this  .
      def   ~(. (default-agent this %|) bowl)
  ++  on-init   `this
  ++  on-save   !>(got)
  ++  on-load   |=(vase `this)
  ++  on-watch  on-watch:def
  ++  on-leave  on-leave:def
  ++  on-peek   on-peek:def
  ++  on-agent  on-agent:def
  ++  on-arvo   on-arvo:def
  ++  on-fail   on-fail:def
  ++  on-poke
    |=  [=mark =vase]
    ^-  (quip card:agent:gall _this)
    ?:  ?=(%test-cards mark)
      [!<((list card:agent:gall) vase) this]
    [~ this(got [mark got])]
  --
::
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
++  get-saved
  |=  saved=vase
  ^-  content-store-saved-state
  =+  !<([[%content-store app=content-store-saved-state] *] saved)
  app
::
++  put-saved
  |=  app=content-store-saved-state
  ^-  vase
  !>([[%content-store app] !>(~)])
::
++  get-marks
  |=  saved=vase
  ^-  (list mark)
  =+  !<([* inner=vase] saved)
  (flop !<((list mark) inner))
::
::  content-result: a content-routing result as it comes up from below
::
++  content-result
  |=  notice=operation-notice:cra
  ^-  vase
  !>  ^-  (list card:agent:gall)
  :_  ~
  :*  %pass  /callback  %agent  [~zod %content-store]
      %poke  %content-routing-result
      !>(notice(reply-path [%~.~ %content-store reply-path.notice]))
  ==
::
::  discovery-result: a content-discovery result as it comes up from below
::
++  discovery-result
  |=  notice=operation-notice:cda
  ^-  vase
  !>  ^-  (list card:agent:gall)
  :_  ~
  :*  %pass  /callback  %agent  [~zod %content-store]
      %poke  %content-discovery-result
      !>(notice(reply-path [%~.~ %content-store reply-path.notice]))
  ==
::
++  get-state
  |=  saved=vase
  ^-  content-store-state
  state:(get-saved saved)
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
  =/  saved=content-store-saved-state  (get-saved on-save:+.initialized)
  =/  peek=(unit (unit cage))
    (on-peek:+.initialized /x/~/content-store/settings)
  =/  settings=content-store-config
    !<(content-store-config q:(need (need peek)))
  =/  loaded  (on-load:~(. agent bowl) (put-saved saved))
  =/  restored=content-store-saved-state  (get-saved on-save:+.loaded)
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
    (on-poke:+.started %test-cards (content-result notice))
  =/  published-state=content-store-state  (get-state on-save:+.published)
  =/  local-publication=local-publication
    (need (~(get by publications.published-state) content))
  =/  result=content-store-result
    (need (~(get by completed.published-state) 0v1))
  =/  got
    %+  on-poke:+.published  %content-store-command
    !>(`content-store-command`[%get 0v2 [%content content]])
  =/  got-state=content-store-state  (get-state on-save:+.got)
  =/  get-result=content-store-result
    (need (~(get by completed.got-state) 0v2))
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent -.started))
    %+  expect-eq
      !>(`(list mark)`~[%content-routing-command %content-routing-command])
    !>((get-marks on-save:+.started))
    %+  expect-eq  !>(1)
    !>((lent ~(tap by pages.started-state)))
    %+  expect-eq  !>(1)
    !>((need (~(get by provider-revisions.started-state) content)))
    (expect !>(?=(%put -.result)))
    (expect !>(?=(%get -.get-result)))
    %+  expect-eq  !>(&)
    !>(originated.local-publication)
    %+  expect-eq  !>(|)
    !>(pinned.local-publication)
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
    (on-poke:+.first %test-cards (content-result first-notice))
  =/  second
    %+  on-poke:+.completed  %content-store-command
    !>(`content-store-command`[%put 0v2 value [~ ~] ~])
  =/  state=content-store-state  (get-state on-save:+.second)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent -.second))
    %+  expect-eq  !>(1)
    !>((lent ~(tap by pages.state)))
    %+  expect-eq  !>(2)
    !>((need (~(get by provider-revisions.state) content)))
  ==
::
++  test-pointer-revision-allocation-and-cas
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  key=name-key  [%demo ~[%latest]]
  =/  automatic=publication-options
    [`[%demo ~[%latest] [%auto ~] ~] ~]
  =/  first
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%put 0v20 value automatic ~])
  =/  first-state=content-store-state  (get-state on-save:+.first)
  =/  first-op=content-store-operation
    (need (~(get by active.first-state) 0v20))
  ?>  ?=(%put -.first-op)
  =/  second
    %+  on-poke:+.first  %content-store-command
    !>(`content-store-command`[%put 0v21 value automatic ~])
  =/  second-state=content-store-state  (get-state on-save:+.second)
  =/  second-op=content-store-operation
    (need (~(get by active.second-state) 0v21))
  ?>  ?=(%put -.second-op)
  =/  compare=publication-options
    [`[%demo ~[%latest] [%cas 2 7] ~] ~]
  =/  compared
    %+  on-poke:+.second  %content-store-command
    !>(`content-store-command`[%put 0v22 value compare ~])
  =/  compared-state=content-store-state  (get-state on-save:+.compared)
  =/  compared-op=content-store-operation
    (need (~(get by active.compared-state) 0v22))
  ?>  ?=(%put -.compared-op)
  =/  stale=publication-options
    [`[%demo ~[%latest] [%cas 2 8] ~] ~]
  =/  rejected
    %+  on-poke:+.compared  %content-store-command
    !>(`content-store-command`[%put 0v23 value stale ~])
  =/  final=content-store-state  (get-state on-save:+.rejected)
  =/  failure=content-store-result
    (need (~(get by completed.final) 0v23))
  ;:  weld
    %+  expect-eq  !>(1)
    !>((need pointer-revision.value.first-op))
    %+  expect-eq  !>(`(unit @da)`~)
    !>(pointer-expires.value.first-op)
    %+  expect-eq  !>(2)
    !>((need pointer-revision.value.second-op))
    %+  expect-eq  !>(7)
    !>((need pointer-revision.value.compared-op))
    %+  expect-eq  !>(7)
    !>((need (~(get by pointer-revisions.final) key)))
    %+  expect-eq  !>(`content-store-result`[%failed %revision-conflict])
    !>(failure)
  ==
::
++  test-explicit-pointer-revision-seeds-automatic-counter
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  explicit=publication-options
    [`[%demo ~[%latest] [%set 12] ~] ~]
  =/  first
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%put 0v24 value explicit ~])
  =/  automatic=publication-options
    [`[%demo ~[%latest] [%auto ~] ~] ~]
  =/  second
    %+  on-poke:+.first  %content-store-command
    !>(`content-store-command`[%put 0v25 value automatic ~])
  =/  state=content-store-state  (get-state on-save:+.second)
  =/  op=content-store-operation  (need (~(get by active.state) 0v25))
  ?>  ?=(%put -.op)
  ;:  weld
    %+  expect-eq  !>(13)
    !>((need pointer-revision.value.op))
    %+  expect-eq  !>(13)
    !>((need (~(get by pointer-revisions.state) [%demo ~[%latest]])))
  ==
::
++  test-pointer-revision-counter-survives-load
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  automatic=publication-options
    [`[%demo ~[%latest] [%auto ~] ~] ~]
  =/  first
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%put 0v26 value automatic ~])
  =/  loaded  (on-load:~(. agent bowl) on-save:+.first)
  =/  second
    %+  on-poke:+.loaded  %content-store-command
    !>(`content-store-command`[%put 0v27 value automatic ~])
  =/  state=content-store-state  (get-state on-save:+.second)
  =/  op=content-store-operation  (need (~(get by active.state) 0v27))
  ?>  ?=(%put -.op)
  ;:  weld
    %+  expect-eq  !>(2)
    !>((need pointer-revision.value.op))
    %+  expect-eq  !>(2)
    !>((need (~(get by pointer-revisions.state) [%demo ~[%latest]])))
  ==
::
++  test-pointer-relative-lifetime-and-zero-rejection
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  expiring=publication-options
    [`[%demo ~[%latest] [%auto ~] `~h6] ~]
  =/  started
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%put 0v28 value expiring ~])
  =/  started-state=content-store-state  (get-state on-save:+.started)
  =/  op=content-store-operation
    (need (~(get by active.started-state) 0v28))
  ?>  ?=(%put -.op)
  =/  invalid=publication-options
    [`[%demo ~[%latest] [%auto ~] `~s0] ~]
  =/  rejected
    %+  on-poke:+.started  %content-store-command
    !>(`content-store-command`[%put 0v29 value invalid ~])
  =/  final=content-store-state  (get-state on-save:+.rejected)
  =/  failure=content-store-result
    (need (~(get by completed.final) 0v29))
  ;:  weld
    %+  expect-eq  !>((add now ~h6))
    !>((need pointer-expires.value.op))
    %+  expect-eq  !>(`content-store-result`[%failed %invalid])
    !>(failure)
    %+  expect-eq  !>(1)
    !>((need (~(get by pointer-revisions.final) [%demo ~[%latest]])))
  ==
::
++  test-pin-local-content-and-unpin
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  content=digest  (digest-cask:cr value)
  =/  initial=content-store-state  (get-state on-save:+.initialized)
  =.  values.initial  (~(put by values.initial) content value)
  =/  loaded
    (on-load:~(. agent bowl) (put-saved [%1 initial %off]))
  =/  started
    %+  on-poke:+.loaded  %content-store-command
    !>(`content-store-command`[%pin 0v30 content ~])
  =/  started-state=content-store-state  (get-state on-save:+.started)
  =/  operation=content-store-operation
    (need (~(get by active.started-state) 0v30))
  ?>  ?=(%pin -.operation)
  =/  pin=pin-operation  value.operation
  =/  publication=publication-result:cra
    (accepted-publication (provider-key:cr content))
  =/  notice=operation-notice:cra
    [/pin/provider/0v30/0v1 [%published publication]]
  =/  completed
    (on-poke:+.started %test-cards (content-result notice))
  =/  completed-state=content-store-state  (get-state on-save:+.completed)
  =/  result=content-store-result
    (need (~(get by completed.completed-state) 0v30))
  ?>  ?=(%pin -.result)
  =/  status=local-publication
    (need (~(get by publications.completed-state) content))
  =/  pins=(set digest)
    !<((set digest) q:(need (need (on-peek:+.completed /x/~/content-store/pins))))
  =/  provider-path=path  /x/~/content-store/provider/(scot %uv content)
  =/  provider-view=local-publication
    !<(local-publication q:(need (need (on-peek:+.completed provider-path))))
  =/  publication-view=(map digest local-publication)
    !<((map digest local-publication) q:(need (need (on-peek:+.completed /x/~/content-store/publications))))
  =/  unpinned
    %+  on-poke:+.completed  %content-store-command
    !>(`content-store-command`[%unpin 0v31 content])
  =/  final=content-store-state  (get-state on-save:+.unpinned)
  =/  final-status=local-publication
    (need (~(get by publications.final) content))
  ;:  weld
    %+  expect-eq  !>((add now ~d1))
    !>(expires.pin)
    %+  expect-eq  !>(|)
    !>(fetched.pin)
    %+  expect-eq
      !>(`pin-result`[content locator.pin 1 (add now ~d1) publication |])
    !>(value.result)
    %+  expect-eq  !>(&)
    !>(pinned.status)
    %+  expect-eq  !>(|)
    !>(originated.status)
    %+  expect-eq  !>(1)
    !>((lent ~(tap in pins)))
    %+  expect-eq  !>(status)
    !>(provider-view)
    %+  expect-eq  !>(status)
    !>((need (~(get by publication-view) content)))
    %+  expect-eq  !>(|)
    !>(pinned.final-status)
    %+  expect-eq  !>(`content-store-result`[%unpin content])
    !>((need (~(get by completed.final) 0v31)))
  ==
::
++  test-zero-pin-lifetime-is-invalid
  =/  initialized  on-init:~(. agent bowl)
  =/  content=digest  (digest-cask:cr [%noun 42])
  =/  failed
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%pin 0v32 content `~s0])
  =/  state=content-store-state  (get-state on-save:+.failed)
  %+  expect-eq  !>(`content-store-result`[%failed %invalid])
  !>((need (~(get by completed.state) 0v32)))
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
    (on-poke:+.started %test-cards (discovery-result notice))
  =/  state=content-store-state  (get-state on-save:+.finished)
  =/  result=content-store-result
    (need (~(get by completed.state) 0v4))
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent -.started))
    %+  expect-eq
      !>(`(list mark)`~[%content-discovery-command %content-discovery-command])
    !>((get-marks on-save:+.started))
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
    (on-load:~(. agent bowl) (put-saved [%1 state %off]))
  =/  observed
    %+  on-poke:+.loaded  %content-store-command
    !>(`content-store-command`[%observe 0v9 %sink /reply])
  =/  finished
    %+  on-poke:+.observed  %content-store-command
    !>(`content-store-command`[%get 0v9 [%content content]])
  =/  final=content-store-state  (get-state on-save:+.finished)
  ;:  weld
    %+  expect-eq  !>(1)
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
    [`[namespace=%demo name=~ revision=[%auto ~] lifetime=~] ~]
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
::
++  test-result-for-wrapped-agent-skips-gall
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  content=digest  (digest-cask:cr value)
  =/  state=content-store-state  (get-state on-save:+.initialized)
  =.  values.state  (~(put by values.state) content value)
  =/  loaded
    (on-load:~(. agent bowl) (put-saved [%1 state %off]))
  =/  observed
    %+  on-poke:+.loaded  %content-store-command
    !>(`content-store-command`[%observe 0v9 %content-store /reply])
  =/  finished
    %+  on-poke:+.observed  %content-store-command
    !>(`content-store-command`[%get 0v9 [%content content]])
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent -.finished))
    %+  expect-eq  !>(`(list mark)`~[%content-store-result])
    !>((get-marks on-save:+.finished))
  ==
::
++  test-put-indexes-its-name-at-once
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  content=digest  (digest-cask:cr value)
  =/  named=publication-options
    [`[%demo ~[%apps %latest] [%auto ~] ~] ~]
  =/  started
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%put 0v40 value named ~])
  =/  name=(unit (unit cage))
    (on-peek:+.started /x/~/content-store/name/~zod/demo/apps/latest)
  =/  cask=(unit (unit cage))
    (on-peek:+.started /x/~/content-store/cask/(scot %uv content))
  ;:  weld
    %+  expect-eq  !>(content)
    !>(!<(digest q:(need (need name))))
    %+  expect-eq  !>(value)
    !>(!<((^cask) q:(need (need cask))))
  ==
::
++  test-named-get-indexes-the-name-when-it-completes
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  content=digest  (digest-cask:cr value)
  =/  state=content-store-state  (get-state on-save:+.initialized)
  =.  values.state  (~(put by values.state) content value)
  =/  loaded
    (on-load:~(. agent bowl) (put-saved [%1 state %off]))
  =/  started
    %+  on-poke:+.loaded  %content-store-command
    !>(`content-store-command`[%get 0v41 [%name ~nec %demo ~[%latest]]])
  =/  before=(unit (unit cage))
    (on-peek:+.started /x/~/content-store/name/~nec/demo/latest)
  =/  body=pointer-body
    :*  %demo  (pointer-key:cr %demo 0x12 ~[%latest])  0x12
        1  ~  [%content content]
    ==
  =/  found=operation-result:cra
    [%pointer [%found [body [1 0x0]]] ~ ~]
  =/  finished
    %+  on-poke:+.started  %test-cards
    (content-result [/get/pointer/0v41/0v1 found])
  =/  after=(unit (unit cage))
    (on-peek:+.finished /x/~/content-store/name/~nec/demo/latest)
  =/  final=content-store-state  (get-state on-save:+.finished)
  ;:  weld
    %+  expect-eq  !>(`(unit (unit cage))`~)
    !>(before)
    %+  expect-eq  !>(content)
    !>(!<(digest q:(need (need after))))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by naming.final)))
    (expect !>(?=([~ %get *] (~(get by completed.final) 0v41))))
  ==
::
++  test-untagged-load-keeps-only-our-names
  =/  initialized  on-init:~(. agent bowl)
  =/  state=content-store-state  (get-state on-save:+.initialized)
  =.  names.state
    %-  ~(gas by names.state)
    :~  [[~nec %demo ~[%latest]] 0v42]
        [[~zod %demo ~[%latest]] 0v43]
    ==
  =/  loaded
    %-  on-load:~(. agent bowl)
    !>([[%content-store [state %debug]] !>(~)])
  =/  saved=content-store-saved-state  (get-saved on-save:+.loaded)
  =/  again
    (on-load:~(. agent bowl) (put-saved [%1 state %off]))
  ;:  weld
    %+  expect-eq
      !>(`(map publisher-name digest)`[[[~zod %demo ~[%latest]] 0v43] ~ ~])
    !>(names.state.saved)
    %+  expect-eq  !>(`content-store-verbosity`%debug)
    !>(verbosity.saved)
    %+  expect-eq  !>(2)
    !>(~(wyt by names.state:(get-saved on-save:+.again)))
  ==
::
++  test-unname-drops-a-name
  =/  initialized  on-init:~(. agent bowl)
  =/  state=content-store-state  (get-state on-save:+.initialized)
  =.  names.state
    %-  ~(gas by names.state)
    :~  [[~nec %demo ~[%latest]] 0v42]
        [[~nec %demo ~[%stable]] 0v43]
    ==
  =/  loaded
    (on-load:~(. agent bowl) (put-saved [%1 state %off]))
  =/  dropped
    %+  on-poke:+.loaded  %content-store-command
    !>(`content-store-command`[%unname ~nec %demo ~[%latest]])
  =/  final=content-store-state  (get-state on-save:+.dropped)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent -.dropped))
    %+  expect-eq
      !>(`(map publisher-name digest)`[[[~nec %demo ~[%stable]] 0v43] ~ ~])
    !>(names.final)
  ==
::
++  test-unname-from-below-skips-gall
  =/  initialized  on-init:~(. agent bowl)
  =/  state=content-store-state  (get-state on-save:+.initialized)
  =.  names.state  (~(put by names.state) [~nec %demo ~[%latest]] 0v42)
  =/  loaded
    (on-load:~(. agent bowl) (put-saved [%1 state %off]))
  =/  dropped
    %+  on-poke:+.loaded  %test-cards
    !>  ^-  (list card:agent:gall)
    :_  ~
    :*  %pass  /unname  %agent  [~zod %content-store]
        %poke  %content-store-command
        !>(`content-store-command`[%unname ~nec %demo ~[%latest]])
    ==
  =/  final=content-store-state  (get-state on-save:+.dropped)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent -.dropped))
    %+  expect-eq  !>(0)
    !>(~(wyt by names.final))
  ==
::
++  test-direct-get-fetches-checks-and-caches
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  content=digest  (digest-cask:cr value)
  =/  =spar:ames  [~nec /g/x/1/app//1/some/page]
  =/  started
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%get 0v60 [%direct content [%scry spar]]])
  =/  heard
    %+  on-arvo:+.started  /~/content-store/scry/(scot %uv 0v60)
    [%ames %sage spar value]
  =/  state=content-store-state  (get-state on-save:+.heard)
  =/  wrong
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%get 0v61 [%direct 0v77 [%scry spar]]])
  =/  lied
    %+  on-arvo:+.wrong  /~/content-store/scry/(scot %uv 0v61)
    [%ames %sage spar value]
  =/  bad=content-store-state  (get-state on-save:+.lied)
  ;:  weld
    %+  expect-eq  !>(`(unit (cask))``value)
    !>((~(get by values.state) content))
    %+  expect-eq  !>(`(set digest)`[content ~ ~])
    !>  !<  (set digest)
        q:(need (need (on-peek:+.heard /x/~/content-store/digests)))
    %+  expect-eq
      !>(`content-store-result`[%get content value `[%scry spar]])
    !>((need (~(get by completed.state) 0v60)))
    %+  expect-eq  !>(`content-store-result`[%failed %digest-mismatch])
    !>((need (~(get by completed.bad) 0v61)))
    %+  expect-eq  !>(0)
    !>(~(wyt by values.bad))
  ==
::
++  test-evict-forgets-a-cask-we-do-not-publish
  =/  initialized  on-init:~(. agent bowl)
  =/  value=(cask)  [%noun 42]
  =/  content=digest  (digest-cask:cr value)
  =/  state=content-store-state  (get-state on-save:+.initialized)
  =.  values.state  (~(put by values.state) content value)
  =/  loaded
    (on-load:~(. agent bowl) (put-saved [%1 state %off]))
  =/  evicted
    %+  on-poke:+.loaded  %test-cards
    !>  ^-  (list card:agent:gall)
    :_  ~
    :*  %pass  /evict  %agent  [~zod %content-store]
        %poke  %content-store-command
        !>(`content-store-command`[%evict content])
    ==
  =/  ours
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%put 0v62 value [~ ~] ~])
  =/  kept
    %+  on-poke:+.ours  %content-store-command
    !>(`content-store-command`[%evict content])
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent -.evicted))
    %+  expect-eq  !>(0)
    !>(~(wyt by values:(get-state on-save:+.evicted)))
    %+  expect-eq  !>(`(unit (cask))``value)
    !>((~(get by values:(get-state on-save:+.kept)) content))
  ==
::
++  test-crash-below-fails-the-operation
  =/  crashing
    %-  agent:content-store-agent
    ^-  agent:gall
    |_  =bowl:gall
    +*  this  .
        def   ~(. (default-agent this %|) bowl)
    ++  on-init   `this
    ++  on-save   !>(~)
    ++  on-load   |=(vase `this)
    ++  on-watch  on-watch:def
    ++  on-leave  on-leave:def
    ++  on-peek   on-peek:def
    ++  on-agent  on-agent:def
    ++  on-arvo   on-arvo:def
    ++  on-fail   on-fail:def
    ++  on-poke   |=([mark vase] !!)
    --
  =/  initialized  on-init:~(. crashing bowl)
  =/  searched
    %+  on-poke:+.initialized  %content-store-command
    !>(`content-store-command`[%search 0v50 ~[%software]])
  =/  state=content-store-state  (get-state on-save:+.searched)
  %+  expect-eq  !>(`content-store-result`[%failed %dependency-failed])
  !>((need (~(get by completed.state) 0v50)))
--
