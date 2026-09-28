::  Unified remote-scry publication, retrieval, and topic-search facade.
::
/-  *kademlia, *kademlia-agent, *content-routing, *content-routing-agent
/-  cd=content-discovery, cda=content-discovery-agent, *content-store
/+  kad=kademlia, cr=content-routing, discovery=content-discovery
/+  default-agent, dbug, verb
|%
+$  card  card:agent:gall
+$  action  [cards=(list card) next=content-store-state]
+$  allocation  [id=@uv next=content-store-state]
+$  revision-allocation
  [valid=? revision=(unit @ud) next=content-store-state]
--
::
%+  verb  |
%-  agent:dbug
=/  kad-cfg=config:kad  [20 20 3 12 %kademlia-urbit-v1]
=/  defaults=content-store-config  [~s30 ~d1 8.388.608]
=|  state=content-store-state
=/  verbosity=content-store-verbosity  %off
=>  |%
::
++  log-enabled
  |=  level=?(%info %debug)
  ^-  ?
  ?-  verbosity
    %off    |
    %info   =(%info level)
    %debug  &
  ==
::
++  log
  |=  [=bowl:gall level=?(%info %debug) event=*]
  ^-  ~
  ?.  (log-enabled level)  ~
  ~&  [dap.bowl level event]
  ~
::
++  valid-id
  |=  id=@
  ^-  ?
  (lte (met 0 id) 64)
::
++  valid-config
  |=  cfg=content-store-config
  ^-  ?
  ?&  (gth request-timeout.cfg 0)
      (gth publication-lifetime.cfg 0)
      (gth max-content-bytes.cfg 0)
  ==
::
++  valid-options
  |=  options=publication-options
  ^-  ?
  ?.  ?~  name.options
        &
      ?&  !=(%$ namespace.u.name.options)
          (name-valid:cr name.u.name.options)
          ?~  lifetime.u.name.options
            &
          (gth u.lifetime.u.name.options 0)
      ==
    |
  ?~  topic.options  &
  ?&  (topic-valid:discovery topic.u.topic.options)
      !=(%$ format.u.topic.options)
  ==
::
++  bump-id
  |=  id=@
  ^-  @uv
  (end 6 +(id))
::
++  take-content-id
  ^-  allocation
  =/  id=@uv  (end 6 next-content.state)
  =.  next-content.state  (bump-id id)
  [id state]
::
++  take-discovery-id
  ^-  allocation
  =/  id=@uv  (end 6 next-discovery.state)
  =.  next-discovery.state  (bump-id id)
  [id state]
::
++  take-pointer-revision
  |=  named=(unit named-publication)
  ^-  revision-allocation
  ?~  named  [& ~ state]
  =/  key=name-key  [namespace.u.named name.u.named]
  =/  current=@ud  (~(gut by pointer-revisions.state) [key 0])
  =/  revision=(unit @ud)
    ?-  -.revision.u.named
      %auto  `+(current)
      %set   `value.revision.u.named
      %cas
        ?.  =(expected.revision.u.named current)  ~
        ?.  (gth value.revision.u.named current)  ~
        `value.revision.u.named
    ==
  ?~  revision  [| ~ state]
  =/  high=@ud  (max current u.revision)
  =.  pointer-revisions.state
    (~(put by pointer-revisions.state) key high)
  [& `u.revision state]
::
++  local-poke
  |=  [our=@p app=@tas =mark payload=vase =wire]
  ^-  card
  :*  %pass  wire
      %agent  [our app]
      %poke  mark  payload
  ==
::
++  content-poke
  |=  [our=@p parent=content-store-id id=@uv command=content-command]
  ^-  card
  (local-poke our %content-routing %content-routing-command !>(command) /lower/content/(scot %uv parent)/(scot %uv id))
::
++  discovery-poke
  |=  [our=@p parent=content-store-id id=@uv command=discovery-command:cda]
  ^-  card
  (local-poke our %content-discovery %content-discovery-command !>(command) /lower/discovery/(scot %uv parent)/(scot %uv id))
::
++  callback-card
  |=  [our=@p id=content-store-id callback=content-store-callback result=content-store-result]
  ^-  card
  =/  notice=content-store-notice  [reply-path.callback result]
  (local-poke our recipient.callback %content-store-result !>(notice) /callback/(scot %uv id))
::
++  forget-content
  |=  [our=@p parent=content-store-id id=@uv]
  ^-  card
  (content-poke our parent id [%forget id])
::
++  forget-discovery
  |=  [our=@p parent=content-store-id id=@uv]
  ^-  card
  (discovery-poke our parent id [%forget id])
::
++  keen-card
  |=  [id=content-store-id =spar:ames]
  ^-  card
  [%pass /scry/(scot %uv id) %keen %.n spar]
::
++  yawn-card
  |=  [id=content-store-id =spar:ames]
  ^-  card
  [%pass /scry/(scot %uv id) %arvo %a %yawn spar]
::
++  wait-card
  |=  [id=content-store-id deadline=@da]
  ^-  card
  [%pass /scry-timeout/(scot %uv id)/(scot %da deadline) %arvo %b %wait deadline]
::
++  rest-card
  |=  [id=content-store-id deadline=@da]
  ^-  card
  [%pass /scry-timeout/(scot %uv id)/(scot %da deadline) %arvo %b %rest deadline]
::
++  finish
  |=  [our=@p id=content-store-id result=content-store-result]
  ^-  action
  =.  active.state  (~(del by active.state) id)
  =.  completed.state  (~(put by completed.state) id result)
  =/  callback=(unit content-store-callback)  (~(get by callbacks.state) id)
  =.  callbacks.state  (~(del by callbacks.state) id)
  ?~  callback  [~ state]
  [[(callback-card our id u.callback result) ~] state]
::
++  fail
  |=  [our=@p id=content-store-id reason=content-store-failure]
  ^-  action
  (finish our id [%failed reason])
::
++  publication-ok
  |=  result=operation-result:cra
  ^-  ?
  ?.  ?=(%published -.result)  |
  !=(~ accepted.value.result)
::
++  advertisement-ok
  |=  result=discovery-result:cda
  ^-  ?
  ?.  ?=(%advertised -.result)  |
  =/  records=(list publication-result:cda)  records.value.result
  ?~  records  |
  =/  walk
    |=  remaining=(list publication-result:cda)
    ^-  ?
    ?~  remaining  &
    ?.  !=(~ accepted.i.remaining)  |
    $(remaining t.remaining)
  (walk records)
::
++  settle-put
  |=  [our=@p id=content-store-id put=put-operation]
  ^-  action
  ?.  ?&(provider-done.put pointer-done.put topic-done.put)
    =.  active.state  (~(put by active.state) id [%put put])
    [~ state]
  ?^  failure.put
    (fail our id u.failure.put)
  =/  result=put-result
    :*  content.put
        locator.put
        (need provider.put)
        pointer.put
        pointer-revision.put
        pointer-expires.put
        topic.put
    ==
  (finish our id [%put result])
::
++  first-scry
  |=  locators=locators
  ^-  (unit locator)
  |-
  ?~  locators  ~
  ?:  ?=(%scry -.i.locators)  `i.locators
  $(locators t.locators)
::
++  provider-scry
  |=  records=providers
  ^-  (unit locator)
  |-
  ?~  records  ~
  =/  record=provider  i.records
  =/  locs=locators  locations.body.record
  |-
  ?~  locs  ^$(records t.records)
  ?.  ?=(%scry -.i.locs)  $(locs t.locs)
  =/  spar=spar:ames  spar.i.locs
  ?.  =(ship.spar (~(node-to-ship kad kad-cfg) provider.body.record))
    $(locs t.locs)
  `i.locs
::
++  begin-provider-query
  |=  [our=@p parent=content-store-id content=digest]
  ^-  action
  =/  allocation=allocation  take-content-id
  =.  state  next.allocation
  =/  lower=@uv  id.allocation
  =.  active.state  (~(put by active.state) parent [%providers content])
  :-  :~  (content-poke our parent lower [%observe lower %content-store /get/providers/(scot %uv parent)/(scot %uv lower)])
          (content-poke our parent lower [%find-providers lower content])
      ==
  state
::
++  begin-scry
  |=  [=bowl:gall id=content-store-id content=digest source=locator]
  ^-  action
  ?.  ?=(%scry -.source)  (fail our.bowl id %unsupported-locator)
  =/  deadline=@da  (add now.bowl request-timeout.config.state)
  =.  active.state  (~(put by active.state) id [%scry content source deadline])
  :-  :~  (keen-card id spar.source)
          (wait-card id deadline)
      ==
  state
::
++  begin-pointer-query
  |=  [our=@p parent=content-store-id query=content-store-query]
  ^-  action
  ?.  ?=(%name -.query)  (fail our parent %invalid)
  =/  allocation=allocation  take-content-id
  =.  state  next.allocation
  =/  lower=@uv  id.allocation
  =/  publisher=node-id
    (~(ship-to-node kad kad-cfg) publisher.query)
  =.  active.state  (~(put by active.state) parent [%pointer query])
  :-  :~  (content-poke our parent lower [%observe lower %content-store /get/pointer/(scot %uv parent)/(scot %uv lower)])
          (content-poke our parent lower [%find-pointer lower namespace.query publisher name.query])
      ==
  state
::
++  start-put
  |=  $:  =bowl:gall
          id=content-store-id
          value=(cask)
          options=publication-options
          lifetime=(unit @dr)
      ==
  ^-  action
  =/  bytes=@ud  (met 3 (jam value))
  ?.  ?&  !=(%$ p.value)
          (valid-options options)
          ?~(lifetime & (gth u.lifetime 0))
      ==
    (fail our.bowl id %invalid)
  ?.  (lte bytes max-content-bytes.config.state)
    (fail our.bowl id %too-large)
  =/  pointer-allocation=revision-allocation
    (take-pointer-revision name.options)
  ?.  valid.pointer-allocation
    (fail our.bowl id %revision-conflict)
  =.  state  next.pointer-allocation
  =/  pointer-revision=(unit @ud)  revision.pointer-allocation
  =/  pointer-expires=(unit @da)
    ?~  name.options  ~
    ?~  lifetime.u.name.options  ~
    `(add now.bowl u.lifetime.u.name.options)
  =/  content=digest  (digest-cask:cr value)
  =/  existing=(unit published-page)  (~(get by pages.state) content)
  =/  allocated=[page=published-page cards=(list card) next=content-store-state]
    ?^  existing  [u.existing ~ state]
    =/  spur=path
      /content/(scot %uv content)/(scot %da now.bowl)/(scot %uv id)
    =/  exact=path
      /g/x/1/content-store//1/content/(scot %uv content)/(scot %da now.bowl)/(scot %uv id)
    =/  locator=locator  [%scry [our.bowl exact]]
    =.  pages.state  (~(put by pages.state) content [spur locator])
    :*  [spur locator]
        ~[[%pass /publish/(scot %uv id) %grow spur value]]
        state
    ==
  =/  page=published-page  page.allocated
  =/  publication=(list card)  cards.allocated
  =.  state  next.allocated
  =.  values.state  (~(put by values.state) content value)
  =/  put=put-operation
    :*  content  locator.page
        |  ~
        ?=(~ name.options)  ~  pointer-revision  pointer-expires
        ?=(~ topic.options)  ~
        ~
    ==
  =.  active.state  (~(put by active.state) id [%put put])
  =/  provider-allocation=allocation  take-content-id
  =.  state  next.provider-allocation
  =/  provider-id=@uv  id.provider-allocation
  =/  duration=@dr
    ?~(lifetime publication-lifetime.config.state u.lifetime)
  =/  expires=@da  (add now.bowl duration)
  =/  previous-revision=@ud
    (~(gut by provider-revisions.state) [content 0])
  =/  provider-revision=@ud  +(previous-revision)
  =.  provider-revisions.state
    (~(put by provider-revisions.state) content provider-revision)
  =/  cards=(list card)
    %+  weld  publication
    :~  (content-poke our.bowl id provider-id [%observe provider-id %content-store /put/provider/(scot %uv id)/(scot %uv provider-id)])
        (content-poke our.bowl id provider-id [%publish-provider provider-id content provider-revision expires ~[locator.page]])
    ==
  =/  with-pointer=[cards=(list card) next=content-store-state]
    ?~  name.options  [cards state]
    =/  pointer-allocation=allocation  take-content-id
    =.  state  next.pointer-allocation
    =/  pointer-id=@uv  id.pointer-allocation
    :-  %+  weld  cards
        :~  (content-poke our.bowl id pointer-id [%observe pointer-id %content-store /put/pointer/(scot %uv id)/(scot %uv pointer-id)])
            (content-poke our.bowl id pointer-id [%publish-pointer pointer-id namespace.u.name.options name.u.name.options (need pointer-revision) pointer-expires [%content content]])
        ==
    state
  =.  cards  cards.with-pointer
  =.  state  next.with-pointer
  =/  with-topic=[cards=(list card) next=content-store-state]
    ?~  topic.options  [cards state]
    =/  topic-allocation=allocation  take-discovery-id
    =.  state  next.topic-allocation
    =/  topic-id=@uv  id.topic-allocation
    :-  %+  weld  cards
        :~  (discovery-poke our.bowl id topic-id [%observe topic-id %content-store /put/topic/(scot %uv id)/(scot %uv topic-id)])
            (discovery-poke our.bowl id topic-id [%advertise topic-id topic.u.topic.options format.u.topic.options content entries.u.topic.options revision.u.topic.options expires])
        ==
    state
  [cards.with-topic next.with-topic]
::
++  start-get
  |=  [=bowl:gall id=content-store-id query=content-store-query]
  ^-  action
  ?-  -.query
    %content
      ?.  (digest-valid:cr digest.query)  (fail our.bowl id %invalid)
      =/  local=(unit (cask))  (~(get by values.state) digest.query)
      ?~  local  (begin-provider-query our.bowl id digest.query)
      =/  page=(unit published-page)  (~(get by pages.state) digest.query)
      =/  source=(unit locator)  ?~(page ~ `locator.u.page)
      (finish our.bowl id [%get digest.query u.local source])
    %name
      ?.  ?&  (lte (met 0 publisher.query) 128)
              !=(%$ namespace.query)
              (name-valid:cr name.query)
          ==
        (fail our.bowl id %invalid)
      (begin-pointer-query our.bowl id query)
  ==
::
++  start-search
  |=  [=bowl:gall id=content-store-id topic=topic-path:cd]
  ^-  action
  ?.  (topic-valid:discovery topic)  (fail our.bowl id %invalid)
  =/  allocation=allocation  take-discovery-id
  =.  state  next.allocation
  =/  lower=@uv  id.allocation
  =.  active.state  (~(put by active.state) id [%search topic])
  :-  :~  (discovery-poke our.bowl id lower [%observe lower %content-store /search/(scot %uv id)/(scot %uv lower)])
          (discovery-poke our.bowl id lower [%browse lower topic])
      ==
  state
::
++  operation-conflict
  |=  id=content-store-id
  ^-  ?
  ?|  (~(has by active.state) id)
      (~(has by completed.state) id)
  ==
--
::
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init
  =.  state  [defaults ~ ~ ~ ~ ~ ~ ~ 0v1 0v1]
  `this
::
++  on-save  !>(`content-store-saved-state`[state verbosity])
::
++  on-load
  |=  old=vase
  =/  saved=content-store-saved-state  !<(content-store-saved-state old)
  =.  state  state.saved
  =.  verbosity  verbosity.saved
  `this
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %content-store-command
    ?>  =(src.bowl our.bowl)
    =/  command=content-store-command  !<(content-store-command vase)
    ?-  -.command
      %observe
        ?>  (valid-id id.command)
        =/  done=(unit content-store-result)
          (~(get by completed.state) id.command)
        ?^  done
          [[(callback-card our.bowl id.command [recipient.command reply-path.command] u.done) ~] this]
        =.  callbacks.state
          (~(put by callbacks.state) id.command [recipient.command reply-path.command])
        `this
      %forget
        ?>  (valid-id id.command)
        =.  completed.state  (~(del by completed.state) id.command)
        =.  callbacks.state  (~(del by callbacks.state) id.command)
        `this
      %set-config
        ?>  (valid-config value.command)
        =.  config.state  value.command
        `this
      %set-verbosity
        =.  verbosity  level.command
        `this
      %put
        ?>  (valid-id id.command)
        ?>  !(operation-conflict id.command)
        =/  action=action
          (start-put bowl id.command value.command options.command lifetime.command)
        [cards.action this(state next.action)]
      %get
        ?>  (valid-id id.command)
        ?>  !(operation-conflict id.command)
        =/  action=action  (start-get bowl id.command query.command)
        [cards.action this(state next.action)]
      %search
        ?>  (valid-id id.command)
        ?>  !(operation-conflict id.command)
        =/  action=action  (start-search bowl id.command topic.command)
        [cards.action this(state next.action)]
    ==
  ::
      %content-routing-result
    ?>  =(src.bowl our.bowl)
    =/  notice=operation-notice:cra  !<(operation-notice:cra vase)
    =/  path=path  reply-path.notice
    ?+    path  `this
        [%put %provider @ @ ~]
      =/  parent=(unit @uv)  (slaw %uv i.t.t.path)
      =/  lower=(unit @uv)  (slaw %uv i.t.t.t.path)
      ?~  parent  `this
      ?~  lower  `this
      =/  forget=card  (forget-content our.bowl u.parent u.lower)
      =/  op=(unit content-store-operation)
        (~(get by active.state) u.parent)
      ?~  op  [[forget ~] this]
      ?.  ?=(%put -.u.op)  [[forget ~] this]
      =/  put=put-operation  value.u.op
      =.  provider-done.put  &
      =?  provider.put  ?=(%published -.result.notice)
        `value.result.notice
      =.  failure.put
        ?^  failure.put  failure.put
        ?.  ?=(%published -.result.notice)  `%dependency-failed
        ?.  (publication-ok result.notice)  `%provider-publication-failed
        ~
      =/  settled=action  (settle-put our.bowl u.parent put)
      [(weld [forget ~] cards.settled) this(state next.settled)]
    ::
        [%put %pointer @ @ ~]
      =/  parent=(unit @uv)  (slaw %uv i.t.t.path)
      =/  lower=(unit @uv)  (slaw %uv i.t.t.t.path)
      ?~  parent  `this
      ?~  lower  `this
      =/  forget=card  (forget-content our.bowl u.parent u.lower)
      =/  op=(unit content-store-operation)
        (~(get by active.state) u.parent)
      ?~  op  [[forget ~] this]
      ?.  ?=(%put -.u.op)  [[forget ~] this]
      =/  put=put-operation  value.u.op
      =.  pointer-done.put  &
      =?  pointer.put  ?=(%published -.result.notice)
        `value.result.notice
      =.  failure.put
        ?^  failure.put  failure.put
        ?.  ?=(%published -.result.notice)  `%dependency-failed
        ?.  (publication-ok result.notice)  `%pointer-publication-failed
        ~
      =/  settled=action  (settle-put our.bowl u.parent put)
      [(weld [forget ~] cards.settled) this(state next.settled)]
    ::
        [%get %pointer @ @ ~]
      =/  parent=(unit @uv)  (slaw %uv i.t.t.path)
      =/  lower=(unit @uv)  (slaw %uv i.t.t.t.path)
      ?~  parent  `this
      ?~  lower  `this
      =/  forget=card  (forget-content our.bowl u.parent u.lower)
      =/  op=(unit content-store-operation)
        (~(get by active.state) u.parent)
      ?~  op  [[forget ~] this]
      ?.  ?=(%pointer -.u.op)  [[forget ~] this]
      ?.  ?=(%pointer -.result.notice)
        =/  failed=action  (fail our.bowl u.parent %dependency-failed)
        [(weld [forget ~] cards.failed) this(state next.failed)]
      =/  selection=pointer-selection  selection.value.result.notice
      ?-  -.selection
        %none
          =/  failed=action  (fail our.bowl u.parent %pointer-not-found)
          [(weld [forget ~] cards.failed) this(state next.failed)]
        %conflict
          =/  failed=action  (fail our.bowl u.parent %pointer-conflict)
          [(weld [forget ~] cards.failed) this(state next.failed)]
        %found
          =/  target=target  target.body.record.selection
          ?-  -.target
            %content
              =/  begun=action
                (begin-provider-query our.bowl u.parent digest.target)
              [(weld [forget ~] cards.begun) this(state next.begun)]
            %direct
              ?~  digest.target
                =/  failed=action
                  (fail our.bowl u.parent %unverifiable-direct)
                [(weld [forget ~] cards.failed) this(state next.failed)]
              =/  source=(unit locator)  (first-scry locations.target)
              ?~  source
                =/  failed=action
                  (fail our.bowl u.parent %unsupported-locator)
                [(weld [forget ~] cards.failed) this(state next.failed)]
              =/  begun=action
                (begin-scry bowl u.parent u.digest.target u.source)
              [(weld [forget ~] cards.begun) this(state next.begun)]
          ==
      ==
    ::
        [%get %providers @ @ ~]
      =/  parent=(unit @uv)  (slaw %uv i.t.t.path)
      =/  lower=(unit @uv)  (slaw %uv i.t.t.t.path)
      ?~  parent  `this
      ?~  lower  `this
      =/  forget=card  (forget-content our.bowl u.parent u.lower)
      =/  op=(unit content-store-operation)
        (~(get by active.state) u.parent)
      ?~  op  [[forget ~] this]
      ?.  ?=(%providers -.u.op)  [[forget ~] this]
      ?.  ?=(%providers -.result.notice)
        =/  failed=action  (fail our.bowl u.parent %dependency-failed)
        [(weld [forget ~] cards.failed) this(state next.failed)]
      =/  records=providers  records.selection.value.result.notice
      ?~  records
        =/  failed=action  (fail our.bowl u.parent %provider-not-found)
        [(weld [forget ~] cards.failed) this(state next.failed)]
      =/  source=(unit locator)  (provider-scry records)
      ?~  source
        =/  failed=action  (fail our.bowl u.parent %unsupported-locator)
        [(weld [forget ~] cards.failed) this(state next.failed)]
      =/  begun=action
        (begin-scry bowl u.parent content.u.op u.source)
      [(weld [forget ~] cards.begun) this(state next.begun)]
    ==
  ::
      %content-discovery-result
    ?>  =(src.bowl our.bowl)
    =/  notice=operation-notice:cda  !<(operation-notice:cda vase)
    =/  path=path  reply-path.notice
    ?+    path  `this
        [%put %topic @ @ ~]
      =/  parent=(unit @uv)  (slaw %uv i.t.t.path)
      =/  lower=(unit @uv)  (slaw %uv i.t.t.t.path)
      ?~  parent  `this
      ?~  lower  `this
      =/  forget=card  (forget-discovery our.bowl u.parent u.lower)
      =/  op=(unit content-store-operation)
        (~(get by active.state) u.parent)
      ?~  op  [[forget ~] this]
      ?.  ?=(%put -.u.op)  [[forget ~] this]
      =/  put=put-operation  value.u.op
      =.  topic-done.put  &
      =?  topic.put  ?=(%advertised -.result.notice)
        `value.result.notice
      =.  failure.put
        ?^  failure.put  failure.put
        ?.  ?=(%advertised -.result.notice)  `%dependency-failed
        ?.  (advertisement-ok result.notice)  `%topic-publication-failed
        ~
      =/  settled=action  (settle-put our.bowl u.parent put)
      [(weld [forget ~] cards.settled) this(state next.settled)]
    ::
        [%search @ @ ~]
      =/  parent=(unit @uv)  (slaw %uv i.t.path)
      =/  lower=(unit @uv)  (slaw %uv i.t.t.path)
      ?~  parent  `this
      ?~  lower  `this
      =/  forget=card  (forget-discovery our.bowl u.parent u.lower)
      =/  op=(unit content-store-operation)
        (~(get by active.state) u.parent)
      ?~  op  [[forget ~] this]
      ?.  ?=(%search -.u.op)  [[forget ~] this]
      ?.  ?=(%topic -.result.notice)
        =/  failed=action  (fail our.bowl u.parent %dependency-failed)
        [(weld [forget ~] cards.failed) this(state next.failed)]
      =/  finished=action
        (finish our.bowl u.parent [%search value.result.notice])
      [(weld [forget ~] cards.finished) this(state next.finished)]
    ==
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?.  ?=(%poke-ack -.sign)  (on-agent:def wire sign)
  ?~  p.sign  `this
  ?.  ?=([%lower ?(%content %discovery) @ @ ~] wire)
    (on-agent:def wire sign)
  =/  parent=(unit @uv)  (slaw %uv i.t.t.wire)
  ?~  parent  `this
  ?.  (~(has by active.state) u.parent)  `this
  =/  failed=action  (fail our.bowl u.parent %dependency-failed)
  [cards.failed this(state next.failed)]
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?:  ?=([%scry @ ~] wire)
    ?.  ?=([%ames %sage *] sign-arvo)  (on-arvo:def wire sign-arvo)
    =/  id=(unit @uv)  (slaw %uv i.t.wire)
    ?~  id  `this
    =/  op=(unit content-store-operation)
      (~(get by active.state) u.id)
    ?~  op  `this
    ?.  ?=(%scry -.u.op)  `this
    =/  source=locator  source.u.op
    ?.  ?=(%scry -.source)  `this
    =/  sage=sage:mess:ames  sage.sign-arvo
    =/  cleanup=(list card)
      ~[(rest-card u.id deadline.u.op) (yawn-card u.id p.sage)]
    ?~  q.sage
      =/  failed=action  (fail our.bowl u.id %remote-scry-empty)
      [(weld cleanup cards.failed) this(state next.failed)]
    =/  page=page  q.sage
    =/  value=(cask)  [p.page q.page]
    ?.  (lte (met 3 (jam value)) max-content-bytes.config.state)
      =/  failed=action  (fail our.bowl u.id %remote-scry-too-large)
      [(weld cleanup cards.failed) this(state next.failed)]
    ?.  (verify-cask:cr content.u.op value)
      =/  failed=action  (fail our.bowl u.id %digest-mismatch)
      [(weld cleanup cards.failed) this(state next.failed)]
    =.  values.state  (~(put by values.state) content.u.op value)
    =/  finished=action
      (finish our.bowl u.id [%get content.u.op value `source])
    [(weld cleanup cards.finished) this(state next.finished)]
  ?:  ?=([%scry-timeout @ @ ~] wire)
    ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
    =/  id=(unit @uv)  (slaw %uv i.t.wire)
    =/  deadline=(unit @da)  (slaw %da i.t.t.wire)
    ?~  id  `this
    ?~  deadline  `this
    =/  op=(unit content-store-operation)
      (~(get by active.state) u.id)
    ?~  op  `this
    ?.  ?=(%scry -.u.op)  `this
    ?.  =(deadline.u.op u.deadline)  `this
    =/  source=locator  source.u.op
    ?.  ?=(%scry -.source)  `this
    =/  failed=action  (fail our.bowl u.id %request-timeout)
    [[(yawn-card u.id spar.source) cards.failed] this(state next.failed)]
  (on-arvo:def wire sign-arvo)
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+    path  (on-peek:def path)
      [%x ~]  [~ ~]
      [%x %settings ~]  ``noun+!>(config.state)
      [%x %verbosity ~]  ``noun+!>(verbosity)
      [%x %operation @ ~]
    =/  id=(unit @uv)  (slaw %uv i.t.t.path)
    ?~  id  ~
    =/  done=(unit content-store-result)
      (~(get by completed.state) u.id)
    ?^  done  ``noun+!>(`content-store-view`[%complete u.done])
    =/  active=(unit content-store-operation)
      (~(get by active.state) u.id)
    ?~  active  ~
    ``noun+!>(`content-store-view`[%running u.active])
  ::
      [%x %content @ ~]
    =/  content=(unit @uv)  (slaw %uv i.t.t.path)
    ?~  content  ~
    ?.  (digest-valid:cr u.content)  ~
    =/  value=(unit (cask))  (~(get by values.state) u.content)
    ?~  value  ~
    =/  page=(cask)  u.value
    ``[p.page !>(q.page)]
  ::
      [%x %publication @ ~]
    =/  content=(unit @uv)  (slaw %uv i.t.t.path)
    ?~  content  ~
    =/  page=(unit published-page)  (~(get by pages.state) u.content)
    ?~  page  ~
    ``noun+!>(u.page)
  ==
::
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
