::  content-discovery-agent: agent wrapper for signed topic records
::
::    usage: %-  agent:content-discovery-agent
::           %-  agent:kademlia-agent
::           your-agent
::
::    The wrapper keeps its wires under /~/content-discovery and serves its
::    scries under /x/~/content-discovery.  It handles the
::    %content-discovery-command and %content-discovery-message marks.  It runs
::    node lookups through the kademlia-agent wrapper below it.
::
/-  *kademlia, *kademlia-agent, *content-routing
/-  *content-discovery, *content-discovery-agent
/+  logic=content-discovery-agent-logic, cd=content-discovery
/+  delivery=bounded-poke, rc=record-crypto
|%
+$  card  card:agent:gall
::
++  agent
  |=  inner=agent:gall
  =|  state=discovery-state
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
          ~&  [dap.bowl %content-discovery level event]
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
            ?.  ?=([%~.~ %content-discovery %operation @ ~] reply-path.notice)  ~
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
                [%~.~ %content-discovery reply-path.command]
              `[%kademlia-command !>(command)]
            ::
                %content-discovery-result
              =/  notice=operation-notice  !<(operation-notice q.cage)
              ?:  ?=([%~.~ *] reply-path.notice)  ~
              `cage
            ==
          ?~  down
            $(new t.new, cards [i.new(p [%~.~ %content-discovery p.i.new]) cards])
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
          |=  [id=operation-id callback=operation-callback result=discovery-result]
          ^-  card
          :*  %pass  /callback/(scot %uv id)
              %agent  [our.bowl recipient.callback]
              %poke  %content-discovery-result
              !>(`operation-notice`[reply-path.callback result])
          ==
        ::
        ::  finish: record a public result and produce its notice, if any.
        ::
        ++  finish
          |=  [id=operation-id result=discovery-result]
          ^-  [(list card) _state]
          =.  completed-public.state
            (~(put by completed-public.state) id result)
          =/  callback=(unit operation-callback)  (~(get by callbacks.state) id)
          ?~  callback  [~ state]
          =.  callbacks.state  (~(del by callbacks.state) id)
          [[(notice-card id u.callback result) ~] state]
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
          =/  task=operation-id  id.i.completions
          =/  owner=(unit operation-id)  (~(get by task-owner.state) task)
          =.  completed.state  (~(del by completed.state) task)
          ?~  owner
            ?>  ?=(%topic -.result.i.completions)
            =^  new  state  (finish task [%topic value.result.i.completions])
            $(completions t.completions, notices (weld (flop new) notices))
          =.  task-owner.state  (~(del by task-owner.state) task)
          =/  batch=(unit advertise-batch)  (~(get by batches.state) u.owner)
          ?~  batch  $(completions t.completions)
          ?>  ?=(%published -.result.i.completions)
          =/  next=advertise-batch  u.batch
          =.  tasks.next  (~(del in tasks.next) task)
          =.  results.next  [value.result.i.completions results.next]
          ?:  ?=(^ tasks.next)
            =.  batches.state  (~(put by batches.state) u.owner next)
            $(completions t.completions)
          =.  batches.state  (~(del by batches.state) u.owner)
          =^  new  state
            %+  finish  u.owner
            :-  %advertised
            %+  sort  results.next
            |=  [a=publication-result b=publication-result]
            ?:  !=(key.a key.b)  (lth key.a key.b)
            (dor identity.a identity.b)
          $(completions t.completions, notices (weld (flop new) notices))
        ::
        ++  records-for
          |=  topic=topic-path
          ^-  records
          %+  scag  max-records-per-key.config.state
          (~(values-for logic engine) (topic-key:cd topic))
        ::
        ++  sign-record
          |=  unsigned=unsigned-record:cd
          ^-  record
          ?-  -.unsigned
            %catalog
              :+  %catalog  body.unsigned
              (sign-digest:rc bowl (catalog-message:cd body.unsigned))
            %edge
              :+  %edge  body.unsigned
              (sign-digest:rc bowl (edge-message:cd body.unsigned))
          ==
        ::
        ++  init
          ^+  cor
          =.  state  ~(init logic engine)
          (emit [~(refresh-card logic engine) ~])
        ::
        ++  load
          |=  saved=discovery-saved-state
          ^+  cor
          =.  state  state.saved
          =.  verbosity  verbosity.saved
          (emit [~(refresh-card logic engine) ~])
        ::
        ++  poke-command
          |=  command=discovery-command
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
            %advertise
              ?>  (~(valid-id logic engine) id.command)
              ?>  (topic-valid:cd topic.command)
              =/  catalog=catalog-reference
                [format.command catalog.command entries.command]
              ?>  (catalog-reference-valid:cd catalog)
              ?>  (lth now.bowl expires.command)
              ?>  !(~(has by batches.state) id.command)
              ?>  !(~(has by active.state) id.command)
              ?>  !(~(has by completed-public.state) id.command)
              =/  remaining=unsigned-records:cd
                %-  advertisement-bodies:cd
                :*  topic.command  ~(self-id logic engine)
                    revision.command  expires.command  catalog
                ==
              =.  batches.state  (~(put by batches.state) id.command [~ ~])
              =|  new=(list card)
              |-
              ?~  remaining
                =/  batch=advertise-batch
                  (need (~(get by batches.state) id.command))
                ?>  ?=(^ tasks.batch)
                =/  ignored
                  %+  log  %info
                  [%operation-start id.command %advertise topic.command]
                (emit new)
              =/  rec=record  (sign-record i.remaining)
              =^  task  state  ~(next-operation-id logic engine)
              =^  started  state  (~(start-publish logic engine) task rec)
              =/  batch=advertise-batch
                (need (~(get by batches.state) id.command))
              =.  tasks.batch  (~(put in tasks.batch) task)
              =.  batches.state  (~(put by batches.state) id.command batch)
              =.  task-owner.state  (~(put by task-owner.state) task id.command)
              $(remaining t.remaining, new (weld new started))
            %browse
              ?>  (~(valid-id logic engine) id.command)
              ?>  (topic-valid:cd topic.command)
              ?>  !(~(has by completed-public.state) id.command)
              =/  ignored
                (log %info [%operation-start id.command %browse topic.command])
              =^  new  state
                (~(start-browse logic engine) id.command topic.command)
              (emit new)
            %observe
              ?>  (~(valid-id logic engine) id.command)
              =/  callback=operation-callback
                [recipient.command reply-path.command]
              =/  result=(unit discovery-result)
                (~(get by completed-public.state) id.command)
              ?^  result
                (emit [(notice-card id.command callback u.result) ~])
              ?>  !(~(has by callbacks.state) id.command)
              =.  callbacks.state
                (~(put by callbacks.state) id.command callback)
              cor
            %forget
              ?>  (~(valid-id logic engine) id.command)
              ?>  !(~(has by batches.state) id.command)
              ?>  !(~(has by active.state) id.command)
              =.  completed-public.state
                (~(del by completed-public.state) id.command)
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
          |=  message=discovery-message
          ^+  cor
          ?.  =(version.message %content-discovery-v1)  cor
          ?-  -.message
            %store
              ?.  (~(valid-id logic engine) id.message)  cor
              =/  decoded=(unit sized-record)
                (~(unpack-record logic engine) payload.message)
              ?~  decoded  cor
              =/  stored=[store-status discovery-state]
                (~(put-replica-sized logic engine) u.decoded)
              =.  state  +.stored
              =/  ignored
                (log %debug [%peer-store src.bowl id.message -.stored])
              =^  new  state
                %^  ~(send-response logic engine)  src.bowl  id.message
                ^-  discovery-message
                [%stored %content-discovery-v1 id.message -.stored]
              (emit new)
            %find-topic
              ?.  (~(valid-id logic engine) id.message)  cor
              ?.  (~(valid-query logic engine) topic.message)  cor
              =/  packed=[count=@ud payload=@]
                (~(pack-records logic engine) (records-for topic.message))
              =/  ignored
                %+  log  %debug
                :*  %peer-find-topic  src.bowl  id.message
                    topic.message  count.packed
                ==
              =^  new  state
                %^  ~(send-response logic engine)  src.bowl  id.message
                ^-  discovery-message
                :*  %topic-records  %content-discovery-v1  id.message
                    count.packed  payload.packed
                ==
              (emit new)
            %stored
              ?.  (~(response-expected logic engine) id.message %.n)  cor
              =/  ignored
                (log %debug [%peer-stored src.bowl id.message status.message])
              (step (~(receive-stored logic engine) id.message status.message))
            %topic-records
              ?.  (~(response-expected logic engine) id.message %.y)  cor
              =/  decoded=(unit sized-records)
                (~(unpack-records logic engine) count.message payload.message)
              ?~  decoded
                (step (~(fail-request logic engine) id.message &))
              =/  ignored
                %+  log  %debug
                [%peer-topic-records src.bowl id.message count.message]
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
    !>([[%content-discovery `discovery-saved-state`[state verbosity]] on-save:og])
  ::
  ++  on-load
    |=  ole=vase
    ^-  (quip card _this)
    ?.  ?=([[%content-discovery *] *] q.ole)
      =/  out  abet:init:(below:up (on-load:og ole))
      [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
    =+  !<([[%content-discovery old=discovery-saved-state] ile=vase] ole)
    =/  out  abet:(below:(load:up old) (on-load:og ile))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-poke
    |=  [=mark =vase]
    ^-  (quip card _this)
    =/  out
      ?+    mark  abet:(below:up (on-poke:og mark vase))
          %content-discovery-command
        abet:(poke-command:up !<(discovery-command vase))
      ::
          %content-discovery-message
        abet:(poke-message:up !<(discovery-message vase))
      ==
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-peek
    |=  =path
    ^-  (unit (unit cage))
    ?.  ?=([%x %~.~ %content-discovery *] path)  (on-peek:og path)
    =/  engine  engine:up
    ?+    t.t.t.path  [~ ~]
        [%settings ~]   ``noun+!>(config.state)
        [%delivery ~]   ``noun+!>(~(summary delivery [now.bowl outbound.state]))
        [%verbosity ~]  ``noun+!>(verbosity)
        [%operation @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.t.t.path)
      ?~  id  ~
      ?.  (~(valid-id logic engine) u.id)  ~
      =/  done=(unit discovery-result)
        (~(get by completed-public.state) u.id)
      ?^  done  ``noun+!>(`discovery-view`[%complete u.done])
      ?.  ?|  (~(has by batches.state) u.id)
              (~(has by active.state) u.id)
          ==
        ~
      ``noun+!>(`discovery-view`[%running ~])
    ::
        [%records @ ~]
      =/  key=(unit @ux)  (slaw %ux i.t.t.t.t.path)
      ?~  key  ~
      ``noun+!>(`records`(~(values-for logic engine) u.key))
    ==
  ::
  ++  on-agent
    |=  [=wire =sign:agent:gall]
    ^-  (quip card _this)
    =/  out
      ?.  ?=([%~.~ %content-discovery *] wire)
        abet:(below:up (on-agent:og wire sign))
      abet:(agent-sign:up t.t.wire sign)
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-arvo
    |=  [=wire =sign-arvo]
    ^-  (quip card _this)
    =/  out
      ?.  ?=([%~.~ %content-discovery *] wire)
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
