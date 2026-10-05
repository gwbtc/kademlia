::  content-routing-agent: agent wrapper for signed content records
::
::    usage: %-  agent:content-routing-agent
::           %-  agent:kademlia-agent
::           your-agent
::
::    The wrapper keeps its wires under /~/content-routing and serves its
::    scries under /x/~/content-routing.  It handles the
::    %content-routing-command and %content-routing-message marks.  It runs
::    node lookups through the kademlia-agent wrapper below it.
::
/-  *kademlia, *kademlia-agent, *content-routing, *content-routing-agent
/+  logic=content-routing-agent-logic, cr=content-routing
/+  delivery=bounded-poke, rc=record-crypto
|%
+$  card  card:agent:gall
::
++  agent
  |=  inner=agent:gall
  =|  state=content-state
  =/  verbosity=verbosity  %off
  =>  |%
      ++  work
        |_  [=bowl:gall cards=(list card)]
        ++  cor     .
        ++  engine  [our.bowl now.bowl src.bowl dap.bowl state verify]
        ++  abet    [cards=(flop cards) inner=inner state=state verbosity=verbosity]
        ::
        ++  log
          |=  [level=log-level event=*]
          ^-  ~
          ?.  ?-  verbosity
                %off    |
                %info   =(%info level)
                %debug  &
              ==
            ~
          ~&  [dap.bowl %content-routing level event]
          ~
        ::
        ++  verify
          |=  sample=[signer=node-id message=digest signature=*]
          ^-  ?
          =/  bad  (check-record:rc bowl sample)
          ?~  bad  &
          =/  ignored  (log %debug [%record-verification-failed u.bad])
          |
        ::
        ::  take: keep cards from below.  A lookup result addressed to
        ::  us resumes its operation.
        ::
        ++  take
          |=  new=(list card)
          ^+  cor
          ?~  new  cor
          =/  found=(unit [id=@uv contacts=(list node-id)])
            ?.  ?=([%pass * %agent ^ %poke %kademlia-result *] i.new)  ~
            ?.  =([our.bowl dap.bowl] +<.q.i.new)  ~
            =/  notice=lookup-notice  !<(lookup-notice q.cage.task.q.i.new)
            ?.  ?=([%~.~ %content-routing %operation @ ~] reply-path.notice)  ~
            =/  id=(unit @uv)  (slaw %uv i.t.t.t.reply-path.notice)
            ?~  id  ~
            ?.  (~(valid-id logic engine) u.id)  ~
            `[u.id contacts.result.notice]
          ?~  found
            $(new t.new, cards [i.new cards])
          =.  cor
            (step (~(receive-lookup logic engine) id.u.found contacts.u.found))
          $(new t.new)
        ::
        ::  emit: namespace our cards.  A lookup goes straight to the
        ::  layer below; a result for the wrapped agent goes straight to
        ::  its +on-poke.
        ::
        ++  emit
          |=  new=(list card)
          ^+  cor
          ?~  new  cor
          ?.  ?=(%pass -.i.new)
            $(new t.new, cards [i.new cards])
          =/  down=(unit cage)
            ?.  ?=([%agent ^ %poke *] q.i.new)  ~
            ?.  =([our.bowl dap.bowl] +<.q.i.new)  ~
            =*  cage  cage.task.q.i.new
            ?+    p.cage  ~
                %kademlia-command
              =/  =command  !<(command q.cage)
              ?.  ?=(%find-for -.command)  ~
              =.  reply-path.command
                [%~.~ %content-routing reply-path.command]
              `[%kademlia-command !>(command)]
            ::
                %content-routing-result
              =/  notice=operation-notice  !<(operation-notice q.cage)
              ?:  ?=([%~.~ *] reply-path.notice)  ~
              `cage
            ==
          ?~  down
            $(new t.new, cards [i.new(p [%~.~ %content-routing p.i.new]) cards])
          =^  out  inner
            (~(on-poke inner bowl(src our.bowl)) u.down)
          =.  cor  (take out)
          $(new t.new)
        ::
        ++  below
          |=  out=(quip card agent:gall)
          ^+  cor
          =.  inner  +.out
          (take -.out)
        ::
        ++  notice-card
          |=  [id=operation-id callback=operation-callback result=operation-result]
          ^-  card
          :*  %pass  /callback/(scot %uv id)
              %agent  [our.bowl recipient.callback]
              %poke  %content-routing-result
              !>(`operation-notice`[reply-path.callback result])
          ==
        ::
        ++  step
          |=  transition=[cards=(list card) update=operation-update]
          ^+  cor
          =.  state  state.update.transition
          =/  completions=(list operation-completion)
            completions.update.transition
          =|  notices=(list card)
          |-
          ?~  completions
            (emit (weld (flop notices) cards.transition))
          =*  completion  i.completions
          =/  ignored
            (log %info [%operation-complete id.completion -.result.completion])
          =/  callback=(unit operation-callback)
            (~(get by callbacks.state) id.completion)
          ?~  callback  $(completions t.completions)
          =.  callbacks.state  (~(del by callbacks.state) id.completion)
          %=  $
            completions  t.completions
            notices
              :_  notices
              (notice-card id.completion u.callback result.completion)
          ==
        ::
        ::
        ::  answer: complete an operation from local records alone
        ::
        ++  answer
          |=  [id=operation-id result=operation-result]
          ^+  cor
          =.  completed.state  (~(put by completed.state) id result)
          =/  callback=(unit operation-callback)
            (~(get by callbacks.state) id)
          ?~  callback  cor
          =.  callbacks.state  (~(del by callbacks.state) id)
          (emit [(notice-card id u.callback result) ~])
        ::
        ++  records-for
          |=  request=query
          ^-  records
          ?-  -.request
            %pointer
              %+  skim  (~(values-for logic engine) key.request)
              |=(rec=record ?=(%pointer -.rec))
            %providers
              %+  scag  max-providers.config.state
              %+  skim
                (~(values-for logic engine) (provider-key:cr content.request))
              |=(rec=record ?=(%provider -.rec))
          ==
        ::
        ++  init
          ^+  cor
          =.  state  ~(init logic engine)
          (emit [~(refresh-card logic engine) ~])
        ::
        ++  load
          |=  saved=content-saved-state
          ^+  cor
          =.  state  state.saved
          =.  verbosity  verbosity.saved
          (emit [~(refresh-card logic engine) ~])
        ::
        ++  poke-command
          |=  command=content-command
          ^+  cor
          ?>  =(src.bowl our.bowl)
          ?-  -.command
            %reset
              =/  old-refresh=@da  refresh-at.state
              =^  delivery-cards  state  ~(reset-state logic engine)
              =.  verbosity  %off
              %-  emit
              %+  weld  ~[[%pass /refresh %arvo %b %rest old-refresh]]
              (weld delivery-cards [~(refresh-card logic engine) ~])
            %publish-pointer
              ?>  (~(valid-id logic engine) id.command)
              ?>  !=(%$ namespace.command)
              ?>  (name-valid:cr name.command)
              ?>  (target-valid:cr target.command)
              =/  publisher=node-id  ~(self-id logic engine)
              =/  key=key
                (pointer-key:cr namespace.command publisher name.command)
              =/  body=pointer-body
                :*  namespace.command  key  publisher
                    revision.command  expires.command  target.command
                ==
              =/  rec=record
                [%pointer body (sign-digest:rc bowl (pointer-message:cr body))]
              =/  ignored
                (log %info [%operation-start id.command %publish-pointer key])
              =^  new  state  (~(start-publish logic engine) id.command rec)
              (emit new)
            %publish-provider
              ?>  (~(valid-id logic engine) id.command)
              ?>  (digest-valid:cr content.command)
              ?>  (locators-valid:cr locations.command)
              =/  body=provider-body
                :*  content.command  ~(self-id logic engine)
                    revision.command  expires.command  locations.command
                ==
              =/  rec=record
                [%provider body (sign-digest:rc bowl (provider-message:cr body))]
              =/  ignored
                %+  log  %info
                [%operation-start id.command %publish-provider content.command]
              =^  new  state  (~(start-publish logic engine) id.command rec)
              (emit new)
            %find-pointer
              ?>  (~(valid-id logic engine) id.command)
              ?>  !=(%$ namespace.command)
              ?>  (name-valid:cr name.command)
              ?>  (identity-valid:cr publisher.command)
              =/  key=key
                (pointer-key:cr namespace.command publisher.command name.command)
              =/  selection=pointer-selection
                %-  select-pointer:cr
                :*  now.bowl  namespace.command  key  publisher.command  verify
                    %+  turn  (records-for [%pointer key])
                    |=  rec=record
                    ?>  ?=(%pointer -.rec)
                    value.rec
                ==
              ?.  ?=(%none -.selection)
                %+  answer  id.command
                [%pointer selection (sy ~(self-id logic engine) ~) ~]
              =/  ignored
                (log %info [%operation-start id.command %find-pointer key])
              =^  new  state
                %+  ~(start-find-pointer logic engine)
                  id.command
                [namespace.command publisher.command name.command]
              (emit new)
            %find-providers
              ?>  (~(valid-id logic engine) id.command)
              ?>  (digest-valid:cr content.command)
              =/  selection=provider-selection
                %:  select-providers:cr
                  now.bowl  content.command  verify
                  %+  turn  (records-for [%providers content.command])
                  |=  rec=record
                  ?>  ?=(%provider -.rec)
                  value.rec
                ==
              ?.  ?=(~ records.selection)
                %+  answer  id.command
                [%providers selection (sy ~(self-id logic engine) ~) ~]
              =/  ignored
                %+  log  %info
                [%operation-start id.command %find-providers content.command]
              =^  new  state
                (~(start-find-providers logic engine) id.command content.command)
              (emit new)
            %observe
              ?>  (~(valid-id logic engine) id.command)
              =/  callback=operation-callback
                [recipient.command reply-path.command]
              =/  result=(unit operation-result)
                (~(get by completed.state) id.command)
              ?^  result
                (emit [(notice-card id.command callback u.result) ~])
              ?>  !(~(has by callbacks.state) id.command)
              =.  callbacks.state
                (~(put by callbacks.state) id.command callback)
              cor
            %forget
              ?>  (~(valid-id logic engine) id.command)
              =.  state  (~(forget logic engine) id.command)
              =.  callbacks.state  (~(del by callbacks.state) id.command)
              cor
            %set-config
              =/  ignored  (log %info [%config-set])
              =.  state  (~(set-config logic engine) value.command)
              (step ~(pump logic engine))
            %set-verbosity
              =.  verbosity  level.command
              =/  ignored  (log %info [%verbosity-set level.command])
              cor
          ==
        ::
        ++  poke-message
          |=  message=content-message
          ^+  cor
          ?.  =(version.message %content-routing-v1)  cor
          ?-  -.message
            %store
              ?.  (~(valid-id logic engine) id.message)  cor
              =/  decoded=(unit sized-record)
                (~(unpack-record logic engine) payload.message)
              ?~  decoded  cor
              =/  stored=[store-status content-state]
                (~(put-replica-sized logic engine) u.decoded)
              =.  state  +.stored
              =/  ignored
                (log %debug [%peer-store src.bowl id.message -.stored])
              =^  new  state
                %^  ~(send-response logic engine)  src.bowl  id.message
                `content-message`[%stored %content-routing-v1 id.message -.stored]
              (emit new)
            %find-records
              ?.  (~(valid-id logic engine) id.message)  cor
              ?.  (~(valid-query logic engine) request.message)  cor
              =/  packed=[count=@ud payload=@]
                (~(pack-records logic engine) (records-for request.message))
              =/  ignored
                %+  log  %debug
                :*  %peer-find-records  src.bowl  id.message
                    -.request.message  count.packed
                ==
              =^  new  state
                %^  ~(send-response logic engine)  src.bowl  id.message
                ^-  content-message
                [%records %content-routing-v1 id.message count.packed payload.packed]
              (emit new)
            %stored
              ?.  (~(response-expected logic engine) id.message %.n)  cor
              =/  ignored
                (log %debug [%peer-stored src.bowl id.message status.message])
              (step (~(receive-stored logic engine) id.message status.message))
            %records
              ?.  (~(response-expected logic engine) id.message %.y)  cor
              =/  decoded=(unit sized-records)
                (~(unpack-records logic engine) count.message payload.message)
              ?~  decoded
                (step (~(fail-request logic engine) id.message &))
              =/  ignored
                (log %debug [%peer-records src.bowl id.message count.message])
              (step (~(receive-records logic engine) id.message u.decoded))
          ==
        ::
        ++  agent-sign
          |=  [=wire =sign:agent:gall]
          ^+  cor
          ?.  ?=([%delivery @ @ ~] wire)  cor
          ?.  ?=(%poke-ack -.sign)  cor
          =/  peer=(unit @p)  (slaw %p i.t.wire)
          =/  id=(unit @ud)  (slaw %ud i.t.t.wire)
          ?~  peer  cor
          ?~  id  cor
          =/  ignored
            ?~  p.sign  ~
            (log %debug [%delivery-poke-failed u.peer u.id])
          (step (~(delivery-ack logic engine) u.peer u.id p.sign))
        ::
        ++  wake
          |=  =wire
          ^+  cor
          ?+    wire  cor
              [%refresh ~]
            =^  new  state  ~(refresh-origins logic engine)
            (emit new)
          ::
              [%delivery-expire @ @ ~]
            =/  peer=(unit @p)  (slaw %p i.t.wire)
            =/  deadline=(unit @da)  (slaw %da i.t.t.wire)
            ?~  peer  cor
            ?~  deadline  cor
            (step (~(delivery-expire logic engine) u.peer u.deadline))
          ::
              [%timeout @ ~]
            =/  request=(unit @uv)  (slaw %uv i.t.wire)
            ?~  request  cor
            ?.  (~(has by pending.state) u.request)  cor
            =/  ignored  (log %debug [%request-timeout u.request])
            (step (~(fail-request logic engine) u.request |))
          ==
        --
      --
  ^-  agent:gall
  |_  =bowl:gall
  +*  this  .
      og    ~(. inner bowl)
      up    ~(. work bowl ~)
  ::
  ++  on-init
    ^-  (quip card _this)
    =/  out  abet:init:(below:up on-init:og)
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-save
    !>([[%content-routing `content-saved-state`[state verbosity]] on-save:og])
  ::
  ++  on-load
    |=  ole=vase
    ^-  (quip card _this)
    ?.  ?=([[%content-routing *] *] q.ole)
      =/  out  abet:init:(below:up (on-load:og ole))
      [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
    =/  old
      !<(content-saved-state (load:delivery (slot 5 ole) ~[%outbound %state]))
    =/  out  abet:(below:(load:up old) (on-load:og !<(vase (slot 3 ole))))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-poke
    |=  [=mark =vase]
    ^-  (quip card _this)
    =/  out
      ?+    mark  abet:(below:up (on-poke:og mark vase))
          %content-routing-command
        abet:(poke-command:up !<(content-command vase))
      ::
          %content-routing-message
        abet:(poke-message:up !<(content-message vase))
      ==
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-peek
    |=  =path
    ^-  (unit (unit cage))
    ?.  ?=([%x %~.~ %content-routing *] path)  (on-peek:og path)
    =/  engine  engine:up
    ?+    t.t.t.path  [~ ~]
        [%settings ~]   ``noun+!>(config.state)
        [%delivery ~]   ``noun+!>(~(summary delivery [now.bowl outbound.state]))
        [%verbosity ~]  ``noun+!>(verbosity)
        [%operation @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.t.t.path)
      ?~  id  ~
      ?.  (~(valid-id logic engine) u.id)  ~
      =/  view=(unit operation-view)  (~(get-operation logic engine) u.id)
      ?~  view  ~
      ``noun+!>(u.view)
    ::
        [%records @ ~]
      =/  key=(unit @ux)  (slaw %ux i.t.t.t.t.path)
      ?~  key  ~
      ``noun+!>(`records`(~(values-for logic engine) u.key))
    ::
        [%pointer @ ~]
      =/  key=(unit @ux)  (slaw %ux i.t.t.t.t.path)
      ?~  key  ~
      :+  ~  ~
      :-  %noun
      !>  ^-  records
      %+  skim  (~(values-for logic engine) u.key)
      |=(rec=record ?=(%pointer -.rec))
    ::
        [%providers @ ~]
      =/  parsed=(unit @uv)  (slaw %uv i.t.t.t.t.path)
      ?~  parsed  ~
      ``noun+!>((records-for:up [%providers `digest`u.parsed]))
    ==
  ::
  ++  on-agent
    |=  [=wire =sign:agent:gall]
    ^-  (quip card _this)
    =/  out
      ?.  ?=([%~.~ %content-routing *] wire)
        abet:(below:up (on-agent:og wire sign))
      abet:(agent-sign:up t.t.wire sign)
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-arvo
    |=  [=wire =sign-arvo]
    ^-  (quip card _this)
    =/  out
      ?.  ?=([%~.~ %content-routing *] wire)
        abet:(below:up (on-arvo:og wire sign-arvo))
      ?.  ?=(%wake +<.sign-arvo)  abet:up
      abet:(wake:up t.t.wire)
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-watch
    |=  =path
    ^-  (quip card _this)
    =/  out  abet:(below:up (on-watch:og path))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-leave
    |=  =path
    ^-  (quip card _this)
    =/  out  abet:(below:up (on-leave:og path))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-fail
    |=  [=term =tang]
    ^-  (quip card _this)
    =/  out  abet:(below:up (on-fail:og term tang))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  --
--
