::  Interactive resource transport and profiling agent layered over Kademlia.
::
/-  *kademlia, *kademlia-agent, *content-routing, *content-routing-agent
/-  cd=content-discovery, cda=content-discovery-agent
/-  *kademlia-demo
/+  kad=kademlia, cr=content-routing, demo=kademlia-demo
/+  default-agent, dbug, verb
|%
+$  card  card:agent:gall
--
::
%+  verb  |
%-  agent:dbug
=/  cfg=config:kad  [20 20 3 12 %kademlia-urbit-v1]
=/  defaults=demo-config  [32.768 4 ~s30 8.388.608 4]
=|  state=demo-state
=>  |%
+$  action  [cards=(list card) next=demo-state]
+$  allocation  [id=@uv next=demo-state]
::  JSON and event helpers.
++  text-number
  |=  [aura=@ta value=@]
  ^-  json
  s+(scot aura value)
::
++  number-json
  |=  value=@ud
  ^-  json
  (numb:enjs:format value)
::
++  phase-json
  |=  [run=run-id =phase details=(list [@t json])]
  ^-  json
  %-  pairs:enjs:format
  %+  weld
    :~  ['type' s+'phase']
        ['run' s+run]
        ['phase' s+(@t phase)]
    ==
  details
::
++  fact
  |=  event=json
  ^-  card
  [%give %fact ~[/events] %json !>(event)]
::
++  phase-card
  |=  [run=run-id =phase details=(list [@t json])]
  ^-  card
  (fact (phase-json run phase details))
::
++  resource-json
  |=  res=resource
  ^-  json
  %-  pairs:enjs:format
  ^-  (list [@t json])
  :~  ['content' `json`(text-number %uv content.res)]
      ['seed' `json`(text-number %ud seed.res)]
      ['size' `json`(number-json size.res)]
      ['mime' `json`s+mime.res]
  ==
::
++  snapshot-json
  |=  =bowl:gall
  ^-  json
  =/  entries=(list (pair digest resource))  ~(tap by resources.state)
  %-  pairs:enjs:format
  ^-  (list [@t json])
  :~  ['type' s+'snapshot']
      ['ship' s+(scot %p our.bowl)]
      ['active' (number-json (lent ~(tap by active.state)))]
      ['resources' a+(turn entries |=(entry=(pair digest resource) (resource-json +.entry)))]
      :-  'config'
      %-  pairs:enjs:format
      :~  ['chunkBytes' (number-json chunk-bytes.config.state)]
          ['window' (number-json window.config.state)]
          ['maxResourceBytes' (number-json max-resource-bytes.config.state)]
      ==
  ==
::
::  Effect constructors.
++  local-poke
  |=  [our=@p app=@tas =mark payload=vase =wire]
  ^-  card
  :*  %pass  wire
      %agent  [our app]
      %poke  mark  payload
  ==
::
++  content-poke
  |=  [our=@p id=@uv run=run-id command=content-command]
  ^-  card
  (local-poke our %content-routing %content-routing-command !>(command) /content/(scot %uv id)/[run])
::
++  discovery-poke
  |=  [our=@p id=@uv run=run-id command=discovery-command:cda]
  ^-  card
  (local-poke our %content-discovery %content-discovery-command !>(command) /discovery/(scot %uv id)/[run])
::
++  kademlia-poke
  |=  [our=@p tag=@tas command=command]
  ^-  card
  (local-poke our %kademlia %kademlia-command !>(command) /kademlia/[tag])
::
++  send-peer
  |=  [ship=@p message=transfer-message]
  ^-  card
  :*  %pass  /peer/(scot %p ship)/(scot %uv id.message)
      %agent  [ship %kademlia-demo]
      %poke  %kademlia-demo-message  !>(message)
  ==
::
++  wait-card
  |=  deadline=@da
  ^-  card
  [%pass /timeout/(scot %da deadline) %arvo %b %wait deadline]
::
++  scry-card
  |=  [run=run-id deadline=@da =spar:ames]
  ^-  card
  [%pass /scry/[run]/(scot %da deadline) %keen %.n spar]
::
++  yawn-card
  |=  [run=run-id deadline=@da =spar:ames]
  ^-  card
  [%pass /scry/[run]/(scot %da deadline) %arvo %a %yawn spar]
::
++  scry-timeout-card
  |=  [run=run-id deadline=@da =spar:ames]
  ^-  card
  =/  encoded=@uw  (jam spar)
  [%pass /scry-timeout/[run]/(scot %da deadline)/(scot %uw encoded) %arvo %b %wait deadline]
::
::  State access and allocation.
++  get-op
  |=  run=run-id
  ^-  (unit operation)
  (~(get by active.state) run)
::
++  put-op
  |=  [run=run-id op=operation]
  ^-  demo-state
  =.  active.state  (~(put by active.state) run op)
  state
::
++  drop-run-requests
  |=  run=run-id
  ^-  demo-state
  =/  entries=(list (pair transfer-id pending-chunk))  ~(tap by requests.state)
  =/  pending=(map transfer-id pending-chunk)  requests.state
  |-
  ?~  entries
    =.  requests.state  pending
    state
  =/  request=pending-chunk  +.i.entries
  =?  pending  =(run run.request)  (~(del by pending) -.i.entries)
  $(entries t.entries)
::
++  finish
  |=  [run=run-id success=? details=(list [@t json])]
  ^-  action
  =.  state  (drop-run-requests run)
  =.  active.state  (~(del by active.state) run)
  ?:  success
    [~[(phase-card run %complete details)] state]
  [~[(phase-card run %failed details)] state]
::
::  Reject a command without disturbing an operation already using its run ID.
++  reject
  |=  [run=run-id reason=@t]
  ^-  action
  [~[(phase-card run %failed ~[['reason' s+reason]])] state]
::
::  Content-routing operation helpers.
++  allocate-content
  ^-  allocation
  =/  id=@uv  next-content-operation.state
  =.  next-content-operation.state  +(id)
  [id state]
::
++  start-provider-query
  |=  [our=@p run=run-id content=digest]
  ^-  action
  =/  allocated=allocation  allocate-content
  =.  state  next.allocated
  =/  id=@uv  id.allocated
  :-  :~  (phase-card run %providers-started ~)
          (content-poke our id run [%observe id %kademlia-demo /fetch-providers/(scot %uv id)/[run]])
          (content-poke our id run [%find-providers id content])
      ==
  state
::
++  start-pointer-query
  |=  [our=@p run=run-id publisher=@p namespace=@tas name=path]
  ^-  action
  =/  allocated=allocation  allocate-content
  =.  state  next.allocated
  =/  id=@uv  id.allocated
  =/  publisher-id=node-id  (~(ship-to-node kad cfg) publisher)
  :-  :~  (phase-card run %pointer-started ~)
          (content-poke our id run [%observe id %kademlia-demo /fetch-pointer/(scot %uv id)/[run]])
          (content-poke our id run [%find-pointer id namespace publisher-id name])
      ==
  state
::
++  forget-content-card
  |=  [our=@p id=@uv run=run-id]
  ^-  card
  (content-poke our id run [%forget id])
::
++  forget-discovery-card
  |=  [our=@p id=@uv run=run-id]
  ^-  card
  (discovery-poke our id run [%forget id])
::
::  Topic-discovery result encoding.
++  topic-json
  |=  topic=(list @tas)
  ^-  json
  a+(turn topic |=(segment=@tas s+(@t segment)))
::
++  catalog-json
  |=  record=catalog-record:cd
  ^-  json
  %-  pairs:enjs:format
  :~  ['publisher' (text-number %ux publisher.body.record)]
      ['revision' (number-json revision.body.record)]
      ['format' s+(@t format.catalog.body.record)]
      ['content' (text-number %uv digest.catalog.body.record)]
      ['entries' (number-json entries.catalog.body.record)]
  ==
::
++  child-json
  |=  child=child-selection:cd
  ^-  json
  =/  supporters=(list node-id)  ~(tap in supporters.child)
  %-  pairs:enjs:format
  :~  ['name' s+(@t name.child)]
      ['supporters' a+(turn supporters |=(id=node-id (text-number %ux id)))]
  ==
::
++  identity-json
  |=  identity=record-identity:cd
  ^-  json
  ?-  -.identity
    %catalog
      %-  pairs:enjs:format
      ~[['type' s+'catalog'] ['publisher' (text-number %ux publisher.identity)]]
    %edge
      %-  pairs:enjs:format
      :~  ['type' s+'edge']
          ['publisher' (text-number %ux publisher.identity)]
          ['source' (topic-json source.identity)]
      ==
  ==
::
::  Transfer scheduler.
++  install-fetch
  |=  [run=run-id fs=fetch-state]
  ^-  demo-state
  =/  old=(unit operation)  (get-op run)
  ?~  old  state
  =/  op=operation  u.old
  =.  kind.op  [%fetch fs]
  (put-op run op)
::
++  schedule-wake
  |=  deadline=@da
  ^-  action
  ?:  ?^(wake.state (lte u.wake.state deadline) |)  [~ state]
  =.  wake.state  `deadline
  [~[(wait-card deadline)] state]
::
++  send-chunk
  |=  $:  =bowl:gall
          run=run-id
          provider=node-id
          offset=@ud
          length=@ud
          retries=@ud
      ==
  ^-  action
  =/  id=transfer-id  next-request.state
  =.  next-request.state  +(id)
  =/  deadline=@da  (add now.bowl request-timeout.config.state)
  =/  pending=pending-chunk  [run provider offset length deadline retries]
  =.  requests.state  (~(put by requests.state) id pending)
  =/  op=(unit operation)  (get-op run)
  ?~  op  [~ state]
  ?.  ?=(%fetch -.kind.u.op)  [~ state]
  =/  fs=fetch-state  state.kind.u.op
  =.  in-flight.fs  +(in-flight.fs)
  =.  state  (install-fetch run fs)
  =/  ship=@p  (~(node-to-ship kad cfg) provider)
  =/  message=transfer-message
    [%chunk-request %kademlia-demo-v1 id (need content.fs) offset length]
  =/  wake-action=action  (schedule-wake deadline)
  =.  state  next.wake-action
  [(weld ~[(send-peer ship message)] cards.wake-action) state]
::
++  dispatch
  |=  [=bowl:gall run=run-id]
  ^-  action
  =/  cards=(list card)  ~
  |-
  =/  op=(unit operation)  (get-op run)
  ?~  op  [(flop cards) state]
  ?.  ?=(%fetch -.kind.u.op)  [(flop cards) state]
  =/  fs=fetch-state  state.kind.u.op
  ?~  provider.fs  [(flop cards) state]
  ?:  (gte in-flight.fs window.config.state)  [(flop cards) state]
  ?~  total.fs
    ?:  !=(0 next-offset.fs)  [(flop cards) state]
    =/  length=@ud  chunk-bytes.config.state
    =.  next-offset.fs  length
    =.  state  (install-fetch run fs)
    =/  out=action  (send-chunk bowl run u.provider.fs 0 length 0)
    =.  state  next.out
    [(flop (weld (flop cards.out) cards)) state]
  ?:  (gte next-offset.fs u.total.fs)  [(flop cards) state]
  =/  remaining=@ud  (sub u.total.fs next-offset.fs)
  =/  length=@ud  (min remaining chunk-bytes.config.state)
  =/  offset=@ud  next-offset.fs
  =.  next-offset.fs  (add offset length)
  =.  state  (install-fetch run fs)
  =/  out=action  (send-chunk bowl run u.provider.fs offset length 0)
  =.  state  next.out
  $(cards (weld (flop cards.out) cards))
::
++  begin-transfer
  |=  [=bowl:gall run=run-id content=digest providers=(list node-id)]
  ^-  action
  ?~  providers
    (finish run | ~[['reason' s+'no-compatible-provider']])
  =/  op=(unit operation)  (get-op run)
  ?~  op  [~ state]
  ?.  ?=(%fetch -.kind.u.op)  [~ state]
  =/  fs=fetch-state  state.kind.u.op
  =.  content.fs  `content
  =.  provider.fs  `i.providers
  =.  providers.fs  t.providers
  =.  total.fs  ~
  =.  mime.fs  ~
  =.  data.fs  0
  =.  received.fs  ~
  =.  received-bytes.fs  0
  =.  next-offset.fs  0
  =.  in-flight.fs  0
  =.  first-byte.fs  |
  =.  state  (install-fetch run fs)
  =/  start=card
    (phase-card run %transfer-started ~[['provider' (text-number %ux i.providers)]])
  =/  dispatched=action  (dispatch bowl run)
  =.  state  next.dispatched
  [[start cards.dispatched] state]
::
::  Retrieve one complete resource through an exact Ames remote-scry locator.
++  begin-scry
  |=  [=bowl:gall run=run-id content=digest provider=node-id =spar:ames]
  ^-  action
  =/  deadline=@da  (add now.bowl request-timeout.config.state)
  =/  started=card
    %-  phase-card
    :*  run  %transfer-started
        ~[ ['provider' (text-number %ux provider)]
           ['transport' s+'scry']
         ]
    ==
  :-  :~  started
          (scry-card run deadline spar)
          (scry-timeout-card run deadline spar)
      ==
  state
::
++  fallback-provider
  |=  [=bowl:gall run=run-id reason=@t]
  ^-  action
  =.  state  (drop-run-requests run)
  =/  op=(unit operation)  (get-op run)
  ?~  op  [~ state]
  ?.  ?=(%fetch -.kind.u.op)  [~ state]
  =/  fs=fetch-state  state.kind.u.op
  ?~  providers.fs
    (finish run | ~[['reason' s+reason]])
  (begin-transfer bowl run (need content.fs) providers.fs)
::
::  Command handlers.
++  start-create
  |=  [=bowl:gall run=run-id seed=@ size=@ud mime=@t]
  ^-  action
  ?.  ?&  (gth size 0)
          (lte size max-resource-bytes.config.state)
      ==
    (finish run | ~[['reason' s+'invalid-size']])
  =/  res=resource  (make-resource:demo seed size mime)
  =.  resources.state  (~(put by resources.state) content.res res)
  :-  :~  (phase-card run %started ~[['kind' s+'create']])
          (phase-card run %complete ~[['resource' (resource-json res)]])
      ==
  state
::
++  start-publish
  |=  $:  =bowl:gall
          run=run-id
          content=digest
          transport=transport
          name=(unit [namespace=@tas name=path revision=@ud])
      ==
  ^-  action
  =/  res=(unit resource)  (~(get by resources.state) content)
  ?~  res  (finish run | ~[['reason' s+'unknown-resource']])
  =/  pub=publication-state  [content name | ?~(name & |) |]
  =/  op=operation  [[%publish pub] now.bowl]
  =.  state  (put-op run op)
  =/  provider-allocation=allocation  allocate-content
  =.  state  next.provider-allocation
  =/  provider-id=@uv  id.provider-allocation
  =/  expires=@da  (add now.bowl ~d1)
  =/  spur=path  /resource/(scot %uv content)/(scot %da now.bowl)/[run]
  ::  A unique spur's first %grow is revision 1, so its exact remote path is known.
  =/  scry-path=path
    /g/x/1/kademlia-demo//1/resource/(scot %uv content)/(scot %da now.bowl)/[run]
  =/  location=locator
    ?-  transport
      %custom  [%custom %kademlia-demo-v1 ~]
      %scry    [%scry [our.bowl scry-path]]
    ==
  =/  publication=(list card)
    ?-  transport
      %custom  ~
      %scry
        =/  payload=resource-payload
          [mime.u.res size.u.res (repeat-byte:demo size.u.res fill.u.res)]
        =.  scry-spurs.state  (~(put in scry-spurs.state) spur)
        ~[[%pass /scry-publish/[run] %grow spur [%kademlia-demo-resource payload]]]
    ==
  =/  cards=(list card)
    %+  weld  publication
    :~  (phase-card run %started ~[['kind' s+'publish']])
        (content-poke our.bowl provider-id run [%observe provider-id %kademlia-demo /publish-provider/(scot %uv provider-id)/[run]])
        (content-poke our.bowl provider-id run [%publish-provider provider-id content 1 expires ~[location]])
    ==
  ?~  name  [cards state]
  =/  pointer-allocation=allocation  allocate-content
  =.  state  next.pointer-allocation
  =/  pointer-id=@uv  id.pointer-allocation
  :-  %+  weld  cards
      :~  (content-poke our.bowl pointer-id run [%observe pointer-id %kademlia-demo /publish-pointer/(scot %uv pointer-id)/[run]])
          (content-poke our.bowl pointer-id run [%publish-pointer pointer-id namespace.u.name name.u.name revision.u.name ~ [%content content]])
      ==
  state
::
++  start-lookup
  |=  [=bowl:gall run=run-id target=@p]
  ^-  action
  =/  op=operation  [[%lookup target] now.bowl]
  =.  state  (put-op run op)
  =/  node=node-id  (~(ship-to-node kad cfg) target)
  :-  :~  (phase-card run %started ~[['kind' s+'lookup']])
          (phase-card run %lookup-started ~[['target' s+(scot %p target)]])
      (kademlia-poke our.bowl run [%find-for node %kademlia-demo /lookup/[run]])
      ==
  state
::
++  start-fetch
  |=  [=bowl:gall run=run-id query=fetch-query]
  ^-  action
  =/  content=(unit digest)
    ?-  -.query
      %content  `digest.query
      %name     ~
    ==
  =/  fs=fetch-state  [run query content ~ ~ ~ ~ 0 ~ 0 0 0 |]
  =/  op=operation  [[%fetch fs] now.bowl]
  =.  state  (put-op run op)
  =/  begun=card  (phase-card run %started ~[['kind' s+'fetch']])
  ?-  -.query
    %content
      =/  started=action  (start-provider-query our.bowl run digest.query)
      [[begun cards.started] next.started]
    %name
      =/  started=action  (start-pointer-query our.bowl run publisher.query namespace.query name.query)
      [[begun cards.started] next.started]
  ==
::
++  start-topic-advertisement
  |=  $:  =bowl:gall
          run=run-id
          content=digest
          topic=(list @tas)
          format=@tas
          revision=@ud
      ==
  ^-  action
  =/  res=(unit resource)  (~(get by resources.state) content)
  ?~  res  (finish run | ~[['reason' s+'unknown-resource']])
  =/  op=operation  [[%advertise-topic content topic] now.bowl]
  =.  state  (put-op run op)
  =/  allocated=allocation  allocate-content
  =.  state  next.allocated
  =/  id=@uv  id.allocated
  =/  expires=@da  (add now.bowl ~d1)
  :-  :~  (phase-card run %started ~[['kind' s+'advertise-topic']])
          (phase-card run %topic-advertise-started ~[['topic' (topic-json topic)]])
          (discovery-poke our.bowl id run [%observe id %kademlia-demo /topic-advertise/(scot %uv id)/[run]])
          (discovery-poke our.bowl id run [%advertise id topic format content 1 revision expires])
      ==
  state
::
++  start-topic-browse
  |=  [=bowl:gall run=run-id topic=(list @tas)]
  ^-  action
  =/  op=operation  [[%browse-topic topic] now.bowl]
  =.  state  (put-op run op)
  =/  allocated=allocation  allocate-content
  =.  state  next.allocated
  =/  id=@uv  id.allocated
  :-  :~  (phase-card run %started ~[['kind' s+'browse-topic']])
          (phase-card run %topic-browse-started ~[['topic' (topic-json topic)]])
          (discovery-poke our.bowl id run [%observe id %kademlia-demo /topic-browse/(scot %uv id)/[run]])
          (discovery-poke our.bowl id run [%browse id topic])
      ==
  state
--
::
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init
  =.  state  [defaults ~ ~ ~ 0v1 0v1 0v1 ~ ~]
  `this
::
++  on-save  !>(state)
::
++  on-load
  |=  old=vase
  =/  current=(unit demo-state)  ((soft demo-state) q.old)
  =/  legacy=(unit demo-state-v1)  ((soft demo-state-v1) q.old)
  =.  state
    ?^  current  u.current
    ?^  legacy
      :*  config.u.legacy  resources.u.legacy  active.u.legacy
          requests.u.legacy  next-request.u.legacy
          next-content-operation.u.legacy  next-lookup.u.legacy
          wake.u.legacy  ~
      ==
    [defaults ~ ~ ~ 0v1 0v1 0v1 ~ ~]
  =.  active.state  ~
  =.  requests.state  ~
  =.  wake.state  ~
  `this
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %kademlia-demo-command
    ?>  =(src.bowl our.bowl)
    =/  command=demo-command  !<(demo-command vase)
    ?-  -.command
      %reset
        =/  cancel=(list card)
          ?~  wake.state  ~
          ~[[%pass /timeout/(scot %da u.wake.state) %arvo %b %rest u.wake.state]]
        =/  culls=(list card)
          %+  turn  ~(tap in scry-spurs.state)
          |=(spur=path [%pass /scry-clear %cull ud+1 spur])
        =.  state  [defaults ~ ~ ~ 0v1 0v1 0v1 ~ ~]
        =/  cards=(list card)
          :~  (kademlia-poke our.bowl %reset [%reset ~])
              (local-poke our.bowl %content-routing %content-routing-command !>(`content-command`[%reset ~]) /content/reset)
              (local-poke our.bowl %content-discovery %content-discovery-command !>(`discovery-command:cda`[%reset ~]) /discovery/reset)
              (fact (snapshot-json bowl))
          ==
        [(weld cancel (weld culls cards)) this]
      %create
        =/  action=action  (start-create bowl run.command seed.command size.command mime.command)
        [cards.action this(state next.action)]
      %publish
        ?:  (~(has by active.state) run.command)
          =/  rejected=action  (reject run.command 'run-already-active')
          [cards.rejected this(state next.rejected)]
        ?.  (lth (lent ~(tap by active.state)) max-active.config.state)
          =/  rejected=action  (reject run.command 'too-many-active-operations')
          [cards.rejected this(state next.rejected)]
        =/  action=action
          (start-publish bowl run.command content.command transport.command name.command)
        [cards.action this(state next.action)]
      %lookup
        ?:  (~(has by active.state) run.command)
          =/  rejected=action  (reject run.command 'run-already-active')
          [cards.rejected this(state next.rejected)]
        ?.  (lth (lent ~(tap by active.state)) max-active.config.state)
          =/  rejected=action  (reject run.command 'too-many-active-operations')
          [cards.rejected this(state next.rejected)]
        =/  action=action  (start-lookup bowl run.command target.command)
        [cards.action this(state next.action)]
      %fetch
        ?:  (~(has by active.state) run.command)
          =/  rejected=action  (reject run.command 'run-already-active')
          [cards.rejected this(state next.rejected)]
        ?.  (lth (lent ~(tap by active.state)) max-active.config.state)
          =/  rejected=action  (reject run.command 'too-many-active-operations')
          [cards.rejected this(state next.rejected)]
        =/  action=action  (start-fetch bowl run.command query.command)
        [cards.action this(state next.action)]
      %advertise-topic
        ?:  (~(has by active.state) run.command)
          =/  rejected=action  (reject run.command 'run-already-active')
          [cards.rejected this(state next.rejected)]
        ?.  (lth (lent ~(tap by active.state)) max-active.config.state)
          =/  rejected=action  (reject run.command 'too-many-active-operations')
          [cards.rejected this(state next.rejected)]
        =/  action=action
          %-  start-topic-advertisement
          [bowl run.command content.command topic.command format.command revision.command]
        [cards.action this(state next.action)]
      %browse-topic
        ?:  (~(has by active.state) run.command)
          =/  rejected=action  (reject run.command 'run-already-active')
          [cards.rejected this(state next.rejected)]
        ?.  (lth (lent ~(tap by active.state)) max-active.config.state)
          =/  rejected=action  (reject run.command 'too-many-active-operations')
          [cards.rejected this(state next.rejected)]
        =/  action=action  (start-topic-browse bowl run.command topic.command)
        [cards.action this(state next.action)]
      %cancel
        =.  state  (drop-run-requests run.command)
        =.  active.state  (~(del by active.state) run.command)
        [[(phase-card run.command %cancelled ~) ~] this]
      %network
        =/  discovery-config=discovery-config:cda
          [20 3 12 request-timeout.command ~d1 ~h12 8 65.536 64 8 10.000]
        =/  cards=(list card)
          :~  (kademlia-poke our.bowl %seeds [%set-seeds seeds.command])
              (kademlia-poke our.bowl %request-timeout [%set-request-timeout request-timeout.command])
              (kademlia-poke our.bowl %refresh-interval [%set-refresh-interval refresh-interval.command])
              (kademlia-poke our.bowl %verbosity [%set-verbosity verbosity.command])
              (discovery-poke our.bowl 0v0 %network-config [%set-config discovery-config])
              (discovery-poke our.bowl 0v0 %network-verbosity [%set-verbosity verbosity.command])
          ==
        [cards this]
    ==
  ::
      %kademlia-result
    =/  notice=lookup-notice  !<(lookup-notice vase)
    ?>  =(src.bowl our.bowl)
    ?.  ?=([%lookup @ ~] reply-path.notice)  `this
    =/  run=run-id  i.t.reply-path.notice
    =/  op=(unit operation)  (get-op run)
    ?~  op  `this
    ?.  ?=(%lookup -.kind.u.op)  `this
    =.  active.state  (~(del by active.state) run)
    =/  contacts-json=(list json)
      %+  turn  contacts.result.notice
      |=(id=node-id (text-number %ux id))
    :_  this
    :~  (phase-card run %lookup-complete ~[['contacts' a+contacts-json]])
        (phase-card run %complete ~[['contacts' a+contacts-json]])
    ==
  ::
      %content-routing-result
    =/  notice=operation-notice  !<(operation-notice vase)
    ?>  =(src.bowl our.bowl)
    ?>  ?=([@ @ @ ~] reply-path.notice)
    =/  tag=@tas  i.reply-path.notice
    =/  id=(unit @uv)  (slaw %uv i.t.reply-path.notice)
    =/  run=run-id  i.t.t.reply-path.notice
    =/  forget=(list card)  ?~(id ~ ~[(forget-content-card our.bowl u.id run)])
    =/  respond
      |=  result=action
      ^-  (quip card _this)
      [(weld forget cards.result) this(state next.result)]
    ?+  tag  [forget this]
      %fetch-pointer
        ?.  ?=(%pointer -.result.notice)
          (respond (finish run | ~[['reason' s+'pointer-query-failed']]))
        =/  selection=pointer-selection  selection.value.result.notice
        ?.  ?=(%found -.selection)
          (respond (finish run | ~[['reason' s+'pointer-not-found']]))
        =/  target=target  target.body.record.selection
        ?.  ?=(%content -.target)
          (respond (finish run | ~[['reason' s+'unsupported-direct-target']]))
        =/  op=(unit operation)  (get-op run)
        ?~  op  [forget this]
        ?.  ?=(%fetch -.kind.u.op)  [forget this]
        =/  fs=fetch-state  state.kind.u.op
        =.  content.fs  `digest.target
        =.  state  (install-fetch run fs)
        =/  started=action  (start-provider-query our.bowl run digest.target)
        =.  state  next.started
        :_  this
        %+  weld  forget
        [(phase-card run %pointer-complete ~[['content' (text-number %uv digest.target)]]) cards.started]
      %fetch-providers
        ?.  ?=(%providers -.result.notice)
          (respond (finish run | ~[['reason' s+'provider-query-failed']]))
        =/  records=providers  records.selection.value.result.notice
        =/  scry-source=(unit [provider=node-id spar=spar:ames])
          =/  pending=providers  records
          |-
          ?~  pending  ~
          =/  record=provider  i.pending
          =/  locators=locators  locations.body.record
          |-
          ?~  locators  ^$(pending t.pending)
          ?.  ?=(%scry -.i.locators)  $(locators t.locators)
          =/  spar=spar:ames  spar.i.locators
          ?.  =(ship.spar (~(node-to-ship kad cfg) provider.body.record))
            $(locators t.locators)
          `[provider.body.record spar]
        =/  providers=(list node-id)
          %+  murn  records
          |=  record=provider
          =/  compatible=?
            %+  lien  locations.body.record
            |=  loc=locator
            ?&  ?=(%custom -.loc)
                =(%kademlia-demo-v1 protocol.loc)
            ==
          ?:(compatible `provider.body.record ~)
        =/  op=(unit operation)  (get-op run)
        ?~  op  [forget this]
        ?.  ?=(%fetch -.kind.u.op)  [forget this]
        =/  fs=fetch-state  state.kind.u.op
        =/  content=digest  (need content.fs)
        =/  begun=action
          ?^  scry-source
            (begin-scry bowl run content provider.u.scry-source spar.u.scry-source)
          ?~  providers
            ?:  ?=(~ records)
              (finish run | ~[['reason' s+'provider-not-found']])
            (finish run | ~[['reason' s+'no-compatible-provider']])
          (begin-transfer bowl run content providers)
        =/  compatible=@ud
          (add (lent providers) ?~(scry-source 0 1))
        =/  discovery=card
          %-  phase-card
          :*  run
              %providers-complete
              ~[ ['records' (number-json (lent records))]
                 ['compatible' (number-json compatible)]
               ]
          ==
        :_  this(state next.begun)
        %+  weld  forget
        [discovery cards.begun]
      %publish-provider
        =/  op=(unit operation)  (get-op run)
        ?~  op  [forget this]
        ?.  ?=(%publish -.kind.u.op)  [forget this]
        =/  pub=publication-state  state.kind.u.op
        =.  provider-done.pub  &
        =.  failed.pub
          ?:  failed.pub  &
          ?:  ?=(%published -.result.notice)
            =(~ accepted.value.result.notice)
          &
        =/  changed=operation  u.op(kind [%publish pub])
        =.  state  (put-op run changed)
        ?.  ?&(provider-done.pub pointer-done.pub)
          [forget this]
        =/  finished=action
          ?:  failed.pub
            (finish run | ~[['reason' s+'publication-rejected']])
            (finish run & ~[['content' (text-number %uv content.pub)]])
        [(weld forget cards.finished) this(state next.finished)]
      %publish-pointer
        =/  op=(unit operation)  (get-op run)
        ?~  op  [forget this]
        ?.  ?=(%publish -.kind.u.op)  [forget this]
        =/  pub=publication-state  state.kind.u.op
        =.  pointer-done.pub  &
        =.  failed.pub
          ?:  failed.pub  &
          ?:  ?=(%published -.result.notice)
            =(~ accepted.value.result.notice)
          &
        =/  changed=operation  u.op(kind [%publish pub])
        =.  state  (put-op run changed)
        ?.  ?&(provider-done.pub pointer-done.pub)
          [forget this]
        =/  finished=action
          ?:  failed.pub
            (finish run | ~[['reason' s+'publication-rejected']])
            (finish run & ~[['content' (text-number %uv content.pub)]])
        [(weld forget cards.finished) this(state next.finished)]
    ==
  ::
      %content-discovery-result
    =/  notice=operation-notice:cda  !<(operation-notice:cda vase)
    ?>  =(src.bowl our.bowl)
    ?>  ?=([@ @ @ ~] reply-path.notice)
    =/  tag=@tas  i.reply-path.notice
    =/  id=(unit @uv)  (slaw %uv i.t.reply-path.notice)
    =/  run=run-id  i.t.t.reply-path.notice
    =/  forget=(list card)
      ?~(id ~ ~[(forget-discovery-card our.bowl u.id run)])
    =/  respond
      |=  result=action
      ^-  (quip card _this)
      [(weld forget cards.result) this(state next.result)]
    ?+  tag  [forget this]
      %topic-advertise
        =/  op=(unit operation)  (get-op run)
        ?~  op  [forget this]
        ?.  ?=(%advertise-topic -.kind.u.op)  [forget this]
        ?.  ?=(%advertised -.result.notice)
          (respond (finish run | ~[['reason' s+'topic-advertisement-failed']]))
        =/  results=(list publication-result:cda)  records.value.result.notice
        =/  accepted=@ud
          %+  roll  results
          |=  [item=publication-result:cda total=@ud]
          (add total (lent ~(tap in accepted.item)))
        =/  rejected=@ud
          %+  roll  results
          |=  [item=publication-result:cda total=@ud]
          (add total (lent ~(tap by rejected.item)))
        =/  timed-out=@ud
          %+  roll  results
          |=  [item=publication-result:cda total=@ud]
          (add total (lent ~(tap in timed-out.item)))
        =/  complete=card
          %-  phase-card
          :*  run  %topic-advertise-complete
              ~[ ['records' (number-json (lent results))]
                 ['accepted' (number-json accepted)]
                 ['rejected' (number-json rejected)]
                 ['timedOut' (number-json timed-out)]
               ]
          ==
        =/  finished=action
          (finish run & ~[['content' (text-number %uv content.kind.u.op)] ['topic' (topic-json topic.kind.u.op)]])
        [(weld forget [complete cards.finished]) this(state next.finished)]
      %topic-browse
        =/  op=(unit operation)  (get-op run)
        ?~  op  [forget this]
        ?.  ?=(%browse-topic -.kind.u.op)  [forget this]
        ?.  ?=(%topic -.result.notice)
          (respond (finish run | ~[['reason' s+'topic-browse-failed']]))
        =/  selected=topic-selection:cd  selection.value.result.notice
        =/  catalogs=(list json)
          (turn catalogs.selected |=(record=catalog-record:cd (catalog-json record)))
        =/  children=(list json)
          (turn children.selected |=(child=child-selection:cd (child-json child)))
        =/  conflicts=(list json)
          %+  turn  ~(tap in conflicts.selected)
          |=  identity=record-identity:cd
          (identity-json identity)
        =/  complete=card
          %-  phase-card
          :*  run  %topic-browse-complete
              ~[ ['topic' (topic-json topic.value.result.notice)]
                 ['catalogs' a+catalogs]
                 ['children' a+children]
                 ['conflicts' a+conflicts]
                 ['responders' (number-json (lent ~(tap in responders.value.result.notice)))]
                 ['timedOut' (number-json (lent ~(tap in timed-out.value.result.notice)))]
               ]
          ==
        =/  finished=action
          (finish run & ~[['catalogCount' (number-json (lent catalogs))] ['childCount' (number-json (lent children))]])
        [(weld forget [complete cards.finished]) this(state next.finished)]
    ==
  ::
      %kademlia-demo-message
    =/  message=transfer-message  !<(transfer-message vase)
    ?.  =(%kademlia-demo-v1 version.message)  `this
    ?.  (lte (met 0 id.message) 64)  `this
    ?.  (digest-valid:cr content.message)  `this
    ?-  -.message
      %chunk-request
        =/  res=(unit resource)  (~(get by resources.state) content.message)
        ?~  res
          =/  reply=transfer-message
            [%unavailable %kademlia-demo-v1 id.message content.message %missing]
          [[(send-peer src.bowl reply) ~] this]
        ?.  ?&  (gth length.message 0)
                (lte length.message chunk-bytes.config.state)
                (lth offset.message size.u.res)
            ==
          =/  reply=transfer-message
            [%unavailable %kademlia-demo-v1 id.message content.message %invalid]
          [[(send-peer src.bowl reply) ~] this]
        =/  length=@ud  (min length.message (sub size.u.res offset.message))
        =/  payload=@  (chunk:demo u.res offset.message length)
        =/  reply=transfer-message
          :*  %chunk  %kademlia-demo-v1  id.message  content.message
              offset.message  size.u.res  mime.u.res  length  payload
          ==
        [[(send-peer src.bowl reply) ~] this]
      %unavailable
        =/  pending=(unit pending-chunk)  (~(get by requests.state) id.message)
        ?~  pending  `this
        ?.  =(src.bowl (~(node-to-ship kad cfg) provider.u.pending))  `this
        =.  requests.state  (~(del by requests.state) id.message)
        =/  op=(unit operation)  (get-op run.u.pending)
        ?~  op  `this
        ?.  ?=(%fetch -.kind.u.op)  `this
        =/  fs=fetch-state  state.kind.u.op
        =.  in-flight.fs  (dec in-flight.fs)
        =.  state  (install-fetch run.u.pending fs)
        =/  failed=action  (fallback-provider bowl run.u.pending 'provider-unavailable')
        [cards.failed this(state next.failed)]
      %chunk
        =/  pending=(unit pending-chunk)  (~(get by requests.state) id.message)
        ?~  pending  `this
        ?.  =(src.bowl (~(node-to-ship kad cfg) provider.u.pending))  `this
        =/  op=(unit operation)  (get-op run.u.pending)
        ?~  op  `this
        ?.  ?=(%fetch -.kind.u.op)  `this
        =/  fs=fetch-state  state.kind.u.op
        ?.  ?&  =(content.message (need content.fs))
                =(offset.message offset.u.pending)
                (chunk-valid:demo content.message offset.message length.u.pending total.message length.message payload.message max-resource-bytes.config.state chunk-bytes.config.state)
            ==
          `this
        =.  requests.state  (~(del by requests.state) id.message)
        =.  in-flight.fs  (dec in-flight.fs)
        ?.  ?&  ?~(total.fs & =(u.total.fs total.message))
                ?~(mime.fs & =(u.mime.fs mime.message))
            ==
          =/  failed=action  (fallback-provider bowl run.u.pending 'inconsistent-resource')
          [cards.failed this(state next.failed)]
        =.  total.fs  `total.message
        =.  mime.fs  `mime.message
        =/  total=@ud  total.message
        =/  mime=@t  mime.message
        ?:  (~(has in received.fs) offset.message)
          =.  state  (install-fetch run.u.pending fs)
          =/  dispatched=action  (dispatch bowl run.u.pending)
          [cards.dispatched this(state next.dispatched)]
        =.  data.fs  (insert-chunk:demo data.fs offset.message payload.message)
        =.  received.fs  (~(put in received.fs) offset.message)
        =.  received-bytes.fs  (add received-bytes.fs length.message)
        =/  first=?  !first-byte.fs
        =.  first-byte.fs  &
        =.  state  (install-fetch run.u.pending fs)
        =/  progress=(list card)
          :~  ?:(first (phase-card run.u.pending %first-byte ~) (phase-card run.u.pending %transfer-progress ~[['received' (number-json received-bytes.fs)] ['total' (number-json total)]]))
          ==
        ?:  =(received-bytes.fs total)
          =/  verified=?
            (verify-resource:demo (need content.fs) mime total data.fs)
          =/  done=action
            ?:  verified
              (finish run.u.pending & ~[['bytes' (number-json total)] ['provider' (text-number %ux (need provider.fs))]])
            (fallback-provider bowl run.u.pending 'digest-mismatch')
          :_  this(state next.done)
          %+  weld  progress
          %+  weld
            :~  (phase-card run.u.pending %transfer-complete ~)
                (phase-card run.u.pending %verify-complete ~)
            ==
          cards.done
        =/  dispatched=action  (dispatch bowl run.u.pending)
        [(weld progress cards.dispatched) this(state next.dispatched)]
    ==
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
    [%events ~]  [[(fact (snapshot-json bowl)) ~] this]
  ==
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?:  ?=([%scry @ @ ~] wire)
    ?.  ?=([%ames %sage *] sign-arvo)  (on-arvo:def wire sign-arvo)
    =/  run=(unit run-id)  (slaw %tas i.t.wire)
    =/  deadline=(unit @da)  (slaw %da i.t.t.wire)
    ?~  run  `this
    ?~  deadline  `this
    =/  op=(unit operation)  (get-op u.run)
    ?~  op  `this
    ?.  ?=(%fetch -.kind.u.op)  `this
    =/  fs=fetch-state  state.kind.u.op
    =/  content=digest  (need content.fs)
    =/  sage=sage:mess:ames  sage.sign-arvo
    =/  cleanup=(list card)
      ~[ [%pass /scry-timeout/[u.run]/(scot %da u.deadline)/(scot %uw (jam p.sage)) %arvo %b %rest u.deadline]
         (yawn-card u.run u.deadline p.sage)
       ]
    ?~  q.sage
      =/  failed=action  (finish u.run | ~[['reason' s+'remote-scry-empty']])
      [(weld cleanup cards.failed) this(state next.failed)]
    =/  page=page  q.sage
    ?.  =(%kademlia-demo-resource p.page)
      =/  failed=action  (finish u.run | ~[['reason' s+'remote-scry-wrong-mark']])
      [(weld cleanup cards.failed) this(state next.failed)]
    =/  decoded=(unit resource-payload)
      ((soft resource-payload) q.page)
    ?~  decoded
      =/  failed=action  (finish u.run | ~[['reason' s+'remote-scry-invalid']])
      [(weld cleanup cards.failed) this(state next.failed)]
    =/  payload=resource-payload  u.decoded
    ?.  ?&  (gth size.payload 0)
            (lte size.payload max-resource-bytes.config.state)
            =((met 3 data.payload) size.payload)
        ==
      =/  failed=action  (finish u.run | ~[['reason' s+'remote-scry-too-large']])
      [(weld cleanup cards.failed) this(state next.failed)]
    =/  verified=?
      (verify-resource:demo content mime.payload size.payload data.payload)
    ?.  verified
      =/  failed=action  (finish u.run | ~[['reason' s+'digest-mismatch']])
      [(weld cleanup cards.failed) this(state next.failed)]
    =/  done=action
      (finish u.run & ~[['bytes' (number-json size.payload)] ['transport' s+'scry']])
    :_  this(state next.done)
    %+  weld  cleanup
    %+  weld
      :~  (phase-card u.run %first-byte ~)
          (phase-card u.run %transfer-complete ~)
          (phase-card u.run %verify-complete ~)
      ==
    cards.done
  ?:  ?=([%scry-timeout @ @ @ ~] wire)
    ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
    =/  run=(unit run-id)  (slaw %tas i.t.wire)
    =/  deadline=(unit @da)  (slaw %da i.t.t.wire)
    =/  encoded=(unit @uw)  (slaw %uw i.t.t.t.wire)
    ?~  run  `this
    ?~  deadline  `this
    ?~  encoded  `this
    ?~  (get-op u.run)  `this
    =/  spar=spar:ames  ;;(spar:ames (cue u.encoded))
    =/  failed=action  (finish u.run | ~[['reason' s+'remote-scry-timeout']])
    [[(yawn-card u.run u.deadline spar) cards.failed] this(state next.failed)]
  ?.  ?=([%timeout @ ~] wire)  (on-arvo:def wire sign-arvo)
  ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
  =/  deadline=(unit @da)  (slaw %da i.t.wire)
  ?~  deadline  `this
  ?.  =(wake.state `u.deadline)  `this
  =.  wake.state  ~
  =/  entries=(list (pair transfer-id pending-chunk))  ~(tap by requests.state)
  =/  cards=(list card)  ~
  |-
  ?~  entries
    [cards this]
  =/  id=transfer-id  -.i.entries
  =/  pending=pending-chunk  +.i.entries
  ?.  (~(has by requests.state) id)
    $(entries t.entries)
  ?:  (gth deadline.pending now.bowl)
    =/  wakes=action  (schedule-wake deadline.pending)
    =.  state  next.wakes
    $(entries t.entries, cards (weld cards cards.wakes))
  =.  requests.state  (~(del by requests.state) id)
  =/  op=(unit operation)  (get-op run.pending)
  ?~  op  $(entries t.entries)
  ?.  ?=(%fetch -.kind.u.op)  $(entries t.entries)
  =/  fs=fetch-state  state.kind.u.op
  =.  in-flight.fs  (dec in-flight.fs)
  =.  state  (install-fetch run.pending fs)
  ?:  =(0 retries.pending)
    =/  retried=action
      (send-chunk bowl run.pending provider.pending offset.pending length.pending 1)
    =.  state  next.retried
    $(entries t.entries, cards (weld cards cards.retried))
  =/  failed=action  (fallback-provider bowl run.pending 'transfer-timeout')
  =.  state  next.failed
  $(entries t.entries, cards (weld cards cards.failed))
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?.  ?=(%poke-ack -.sign)  (on-agent:def wire sign)
  ?~  p.sign  `this
  ?:  ?=([%kademlia @ ~] wire)
    =/  run=(unit @tas)  (slaw %tas i.t.wire)
    ?~  run  `this
    ?~  (get-op u.run)  `this
    =/  failed=action  (finish u.run | ~[['reason' s+'kademlia-unavailable']])
    [cards.failed this(state next.failed)]
  ?:  ?=([%content @ @ ~] wire)
    =/  run=(unit @tas)  (slaw %tas i.t.t.wire)
    ?~  run  `this
    ?~  (get-op u.run)  `this
    =/  failed=action  (finish u.run | ~[['reason' s+'content-routing-unavailable']])
    [cards.failed this(state next.failed)]
  ?:  ?=([%discovery @ @ ~] wire)
    =/  run=(unit @tas)  (slaw %tas i.t.t.wire)
    ?~  run  `this
    ?~  (get-op u.run)  `this
    =/  failed=action  (finish u.run | ~[['reason' s+'content-discovery-unavailable']])
    [cards.failed this(state next.failed)]
  ?:  ?=([%peer @ @ ~] wire)
    =/  id=(unit @uv)  (slaw %uv i.t.t.wire)
    ?~  id  `this
    =/  pending=(unit pending-chunk)  (~(get by requests.state) u.id)
    ?~  pending  `this
    =.  requests.state  (~(del by requests.state) u.id)
    =/  op=(unit operation)  (get-op run.u.pending)
    ?~  op  `this
    ?.  ?=(%fetch -.kind.u.op)  `this
    =/  fs=fetch-state  state.kind.u.op
    =.  in-flight.fs  (dec in-flight.fs)
    =.  state  (install-fetch run.u.pending fs)
    =/  failed=action  (fallback-provider bowl run.u.pending 'provider-unavailable')
    [cards.failed this(state next.failed)]
  (on-agent:def wire sign)
++  on-leave  on-leave:def
++  on-fail   on-fail:def
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
    [%x %state ~]  ``noun+!>(state)
    [%x %resources ~]  ``noun+!>(~(val by resources.state))
    [%x %snapshot ~]  ``json+!>((snapshot-json bowl))
  ==
--
