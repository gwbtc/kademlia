::  Signed, leased topic-record transport layered over %kademlia.
::
/-  *kademlia, *kademlia-agent, *content-discovery, *content-discovery-agent
/+  logic=content-discovery-agent-logic, kad=kademlia, cd=content-discovery
/+  delivery=bounded-poke
/+  default-agent, dbug, verb
|%
+$  card  card:agent:gall
--
::
%+  verb  |
%-  agent:dbug
=|  state=discovery-state
=/  verbosity=verbosity  %off
=>  |%
::
++  log-enabled
  |=  level=log-level
  ^-  ?
  ?-  verbosity
    %off    |
    %info   =(%info level)
    %debug  &
  ==
::
++  log
  |=  [=bowl:gall level=log-level event=*]
  ^-  ~
  ?.  (log-enabled level)  ~
  ~&  [dap.bowl level event]
  ~
::
++  sign-digest
  |=  [=bowl:gall message=digest]
  ^-  record-signature
  =/  life=@ud
    .^(@ud %j /(scot %p our.bowl)/life/(scot %da now.bowl)/(scot %p our.bowl))
  =/  secret=ring
    .^(ring %j /(scot %p our.bowl)/vein/(scot %da now.bowl)/(scot %ud life))
  =/  cub  (nol:nu:cric:crypto secret)
  [life (sigh:as:cub message)]
::
++  fake-public
  |=  ship=@p
  ^-  pass
  =/  cub  (pit:nu:cric:crypto 512 ship %b ~)
  pub:ex:cub
::
++  normalize-public
  |=  raw=*
  ^-  (unit [crypto-suite=@ud =pass])
  ?@  raw  ~
  ?.  =(~ -.raw)  ~
  =/  value=*  +.raw
  ?@  value  `[1 `pass`value]
  ?.  ?&  ?=(@ -.value)
          ?=(@ +.value)
      ==
    ~
  `[`@ud`-.value `pass`+.value]
::
++  verify-record
  |=  [=bowl:gall signer=node-id message=digest signature=*]
  ^-  ?
  =/  sig=record-signature  ;;(record-signature signature)
  =/  ship=@p  (~(node-to-ship kad [20 20 3 12 %kademlia-urbit-v1]) signer)
  =/  raw=*
    .^  *
      %j
      /(scot %p our.bowl)/puby/(scot %da now.bowl)/(scot %p ship)/(scot %ud life.sig)
    ==
  =/  public=(unit [crypto-suite=@ud =pass])  (normalize-public raw)
  =/  public=(unit [crypto-suite=@ud =pass])
    ?^  public  public
    =/  fake=?
      .^(? %j /(scot %p our.bowl)/fake/(scot %da now.bowl))
    ?.  ?&  fake
            =(1 life.sig)
        ==
      ~
    `[1 (fake-public ship)]
  ?~  public
    =/  ignored  (log bowl %debug [%record-verification-failed ship life.sig %no-public-key])
    |
  ?.  ?=(?(%1 %2) crypto-suite.u.public)
    =/  ignored
      (log bowl %debug [%record-verification-failed ship life.sig %unsupported-suite])
    |
  =/  them  (com:nu:cric:crypto pass.u.public)
  =/  valid  (safe:as:them value.sig message)
  ?.  valid
    =/  ignored  (log bowl %debug [%record-verification-failed ship life.sig %bad-signature])
    |
  &
::
++  records-for
  |=  [=bowl:gall state=discovery-state topic=topic-path]
  ^-  records
  =/  verify=verifier
    |=  sample=[signer=node-id message=digest signature=*]
    (verify-record bowl sample)
  =/  engine  [our.bowl now.bowl src.bowl state verify]
  =/  key=key  (topic-key:cd topic)
  =/  all=records  (~(values-for logic engine) key)
  (scag max-records-per-key.config.state all)
::
++  sign-record
  |=  [=bowl:gall unsigned=unsigned-record:cd]
  ^-  record
  ?-  -.unsigned
    %catalog
      [%catalog body.unsigned (sign-digest bowl (catalog-message:cd body.unsigned))]
    %edge
      [%edge body.unsigned (sign-digest bowl (edge-message:cd body.unsigned))]
  ==
::
++  operation-notice-card
  |=  $:  our=@p
          id=operation-id
          callback=operation-callback
          result=discovery-result
      ==
  ^-  card
  =/  notice=operation-notice  [reply-path.callback result]
  :*  %pass  /callback/(scot %uv id)
      %agent  [our recipient.callback]
      %poke  %content-discovery-result  !>(notice)
  ==
::
++  finish-public
  |=  [=bowl:gall id=operation-id result=discovery-result]
  ^-  [(list card) discovery-state]
  =.  completed-public.state
    (~(put by completed-public.state) id result)
  =/  callback=(unit operation-callback)  (~(get by callbacks.state) id)
  ?~  callback  [~ state]
  =.  callbacks.state  (~(del by callbacks.state) id)
  [[(operation-notice-card our.bowl id u.callback result) ~] state]
::
++  apply-completions
  |=  [=bowl:gall completions=(list operation-completion)]
  ^-  [(list card) discovery-state]
  =/  cards=(list card)  ~
  |-
  ?~  completions  [(flop cards) state]
  =/  completion=operation-completion  i.completions
  =/  task=operation-id  id.completion
  =/  owner=(unit operation-id)  (~(get by task-owner.state) task)
  ?~  owner
    ?>  ?=(%topic -.result.completion)
    =.  completed.state  (~(del by completed.state) task)
    =/  result=discovery-result  [%topic value.result.completion]
    =/  finished=[(list card) discovery-state]
      (finish-public bowl task result)
    =.  state  +.finished
    $(completions t.completions, cards (weld (flop -.finished) cards))
  =/  batch-id=operation-id  u.owner
  =/  batch=(unit advertise-batch)  (~(get by batches.state) batch-id)
  ?~  batch
    =.  task-owner.state  (~(del by task-owner.state) task)
    =.  completed.state  (~(del by completed.state) task)
    $(completions t.completions)
  ?>  ?=(%published -.result.completion)
  =/  next=advertise-batch  u.batch
  =.  tasks.next  (~(del in tasks.next) task)
  =.  results.next  [value.result.completion results.next]
  =.  task-owner.state  (~(del by task-owner.state) task)
  =.  completed.state  (~(del by completed.state) task)
  ?:  ?=(^ tasks.next)
    =.  batches.state  (~(put by batches.state) batch-id next)
    $(completions t.completions)
  =.  batches.state  (~(del by batches.state) batch-id)
  =/  ordered=(list publication-result)
    %+  sort  results.next
    |=  [a=publication-result b=publication-result]
    ?:  !=(key.a key.b)  (lth key.a key.b)
    (dor identity.a identity.b)
  =/  result=discovery-result  [%advertised ordered]
  =/  finished=[(list card) discovery-state]
    (finish-public bowl batch-id result)
  =.  state  +.finished
  $(completions t.completions, cards (weld (flop -.finished) cards))
::
++  apply-operation-transition
  |=  $:  =bowl:gall
          transition=[cards=(list card) update=operation-update]
      ==
  ^-  [(list card) discovery-state]
  =/  out=discovery-state  state.update.transition
  =.  state  out
  =/  completed=[(list card) discovery-state]
    (apply-completions bowl completions.update.transition)
  [(weld -.completed cards.transition) +.completed]
--
::
^-  agent:gall
|_  =bowl:gall
+*  this    .
    def     ~(. (default-agent this %|) bowl)
    verify
      |=(sample=[signer=node-id message=digest signature=*] (verify-record bowl sample))
    engine  [our.bowl now.bowl src.bowl state verify]
::
++  on-init
  ^-  (quip card _this)
  =.  state  ~(init logic engine)
  [[~(refresh-card logic engine) ~] this]
::
++  on-save  !>(`discovery-saved-state`[state verbosity])
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  saved=discovery-saved-state  !<(discovery-saved-state old)
  =.  state  state.saved
  =.  verbosity  verbosity.saved
  [[~(refresh-card logic engine) ~] this]
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %content-discovery-command
    ?>  =(src.bowl our.bowl)
    =/  command=discovery-command  !<(discovery-command vase)
    ?-  -.command
      %reset
        =/  old-refresh=@da  refresh-at.state
        =^  delivery-cards  state  ~(reset-state logic engine)
        =.  verbosity  %off
        :_  this
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
        =/  publisher=node-id  ~(self-id logic engine)
        =/  bodies=unsigned-records:cd
          %-  advertisement-bodies:cd
          [topic.command publisher revision.command expires.command catalog]
        =.  batches.state  (~(put by batches.state) id.command [~ ~])
        =/  cards=(list card)  ~
        =/  remaining=unsigned-records:cd  bodies
        |-
        ?~  remaining
          =/  batch=advertise-batch
            (need (~(get by batches.state) id.command))
          ?>  ?=(^ tasks.batch)
          =/  ignored  (log bowl %info [%operation-start id.command %advertise topic.command])
          [cards this]
        =/  rec=record  (sign-record bowl i.remaining)
        =^  task  state  ~(next-operation-id logic engine)
        =^  started  state  (~(start-publish logic engine) task rec)
        =/  batch=advertise-batch
          (need (~(get by batches.state) id.command))
        =.  tasks.batch  (~(put in tasks.batch) task)
        =.  batches.state  (~(put by batches.state) id.command batch)
        =.  task-owner.state  (~(put by task-owner.state) task id.command)
        $(remaining t.remaining, cards (weld cards started))
      %browse
        ?>  (~(valid-id logic engine) id.command)
        ?>  (topic-valid:cd topic.command)
        ?>  !(~(has by completed-public.state) id.command)
        =/  ignored  (log bowl %info [%operation-start id.command %browse topic.command])
        =^  cards  state  (~(start-browse logic engine) id.command topic.command)
        [cards this]
      %observe
        ?>  (~(valid-id logic engine) id.command)
        =/  callback=operation-callback
          [recipient.command reply-path.command]
        =/  result=(unit discovery-result)
          (~(get by completed-public.state) id.command)
        ?^  result
          [[(operation-notice-card our.bowl id.command callback u.result) ~] this]
        ?>  !(~(has by callbacks.state) id.command)
        =.  callbacks.state
          (~(put by callbacks.state) id.command callback)
        `this
      %forget
        ?>  (~(valid-id logic engine) id.command)
        ?>  !(~(has by batches.state) id.command)
        ?>  !(~(has by active.state) id.command)
        =.  completed-public.state
          (~(del by completed-public.state) id.command)
        =.  callbacks.state  (~(del by callbacks.state) id.command)
        `this
      %set-config
        =/  ignored  (log bowl %info [%config-set])
        =.  state  (~(set-config logic engine) value.command)
        =/  transition=[cards=(list card) update=operation-update]
          ~(pump logic engine)
        =^  cards  state
          (apply-operation-transition bowl transition)
        [cards this]
      %set-verbosity
        =.  verbosity  level.command
        =/  ignored  (log bowl %info [%verbosity-set level.command])
        `this
    ==
  ::
      %kademlia-result
    ?>  =(src.bowl our.bowl)
    =/  notice=lookup-notice  !<(lookup-notice vase)
    ?.  ?=([%operation @ ~] reply-path.notice)  `this
    =/  id=(unit @uv)  (slaw %uv i.t.reply-path.notice)
    ?~  id  `this
    ?.  (~(valid-id logic engine) u.id)  `this
    =/  transition=[cards=(list card) update=operation-update]
      (~(receive-lookup logic engine) u.id contacts.result.notice)
    =^  cards  state
      (apply-operation-transition bowl transition)
    [cards this]
  ::
      %content-discovery-message
    =/  message=discovery-message  !<(discovery-message vase)
    ?.  =(version.message %content-discovery-v1)  `this
    ?-  -.message
      %store
        ?.  (~(valid-id logic engine) id.message)  `this
        =/  decoded=(unit sized-record)  (~(unpack-record logic engine) payload.message)
        ?~  decoded  `this
        =/  stored=[store-status discovery-state]
          (~(put-replica-sized logic engine) u.decoded)
        =.  state  +.stored
        =/  ignored  (log bowl %debug [%peer-store src.bowl id.message -.stored])
        =/  response=discovery-message  [%stored %content-discovery-v1 id.message -.stored]
        =^  cards  state
          (~(send-response logic engine) src.bowl id.message response)
        [cards this]
      %find-topic
        ?.  (~(valid-id logic engine) id.message)  `this
        ?.  (~(valid-query logic engine) topic.message)  `this
        =/  values=records  (records-for bowl state topic.message)
        =/  packed=[count=@ud payload=@]  (~(pack-records logic engine) values)
        =/  ignored
          (log bowl %debug [%peer-find-topic src.bowl id.message topic.message count.packed])
        =/  response=discovery-message
          [%topic-records %content-discovery-v1 id.message count.packed payload.packed]
        =^  cards  state
          (~(send-response logic engine) src.bowl id.message response)
        [cards this]
      %stored
        ?.  (~(response-expected logic engine) id.message %.n)  `this
        =/  ignored  (log bowl %debug [%peer-stored src.bowl id.message status.message])
        =/  transition=[cards=(list card) update=operation-update]
          (~(receive-stored logic engine) id.message status.message)
        =^  cards  state
          (apply-operation-transition bowl transition)
        [cards this]
      %topic-records
        ?.  (~(response-expected logic engine) id.message %.y)  `this
        =/  decoded=(unit sized-records)
          (~(unpack-records logic engine) count.message payload.message)
        ?~  decoded
          =/  transition=[cards=(list card) update=operation-update]
            (~(fail-request logic engine) id.message &)
          =^  cards  state
            (apply-operation-transition bowl transition)
          [cards this]
        =/  ignored  (log bowl %debug [%peer-topic-records src.bowl id.message count.message])
        =/  transition=[cards=(list card) update=operation-update]
          (~(receive-records logic engine) id.message u.decoded)
        =^  cards  state
          (apply-operation-transition bowl transition)
        [cards this]
    ==
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+    path  (on-peek:def path)
      [%x ~]             [~ ~]
      [%x %settings ~]   ``noun+!>(config.state)
      [%x %delivery ~]   ``noun+!>(~(summary delivery [now.bowl outbound.state]))
      [%x %verbosity ~]  ``noun+!>(verbosity)
      [%x %operation ~]  [~ ~]
      [%x %operation @ ~]
    =/  id=(unit @uv)  (slaw %uv i.t.t.path)
    ?~  id  ~
    ?.  (~(valid-id logic engine) u.id)  ~
    =/  done=(unit discovery-result)
      (~(get by completed-public.state) u.id)
    ?^  done  ``noun+!>(`discovery-view`[%complete u.done])
    ?:  ?|  (~(has by batches.state) u.id)
            (~(has by active.state) u.id)
        ==
      ``noun+!>(`discovery-view`[%running ~])
    ~
  ::
      [%x %records @ ~]
    =/  key=(unit @ux)  (slaw %ux i.t.t.path)
    ?~  key  ~
    =/  values=records  (~(values-for logic engine) u.key)
    ``noun+!>(values)
  ::
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?.  ?=([%delivery @ @ ~] wire)  (on-agent:def wire sign)
  ?.  ?=(%poke-ack -.sign)  (on-agent:def wire sign)
  =/  peer=(unit @p)  (slaw %p i.t.wire)
  =/  id=(unit @ud)  (slaw %ud i.t.t.wire)
  ?~  peer  `this
  ?~  id  `this
  =/  transition=[cards=(list card) update=operation-update]
    (~(delivery-ack logic engine) u.peer u.id p.sign)
  =/  ignored
    ?~  p.sign  ~
    (log bowl %debug [%delivery-poke-failed u.peer u.id])
  =^  cards  state
    (apply-operation-transition bowl transition)
  [cards this]
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?:  =(/refresh wire)
    ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
    =^  cards  state  ~(refresh-origins logic engine)
    [cards this]
  ?:  ?=([%delivery-expire @ @ ~] wire)
    ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
    =/  peer=(unit @p)  (slaw %p i.t.wire)
    =/  deadline=(unit @da)  (slaw %da i.t.t.wire)
    ?~  peer  `this
    ?~  deadline  `this
    =/  transition=[cards=(list card) update=operation-update]
      (~(delivery-expire logic engine) u.peer u.deadline)
    =^  cards  state
      (apply-operation-transition bowl transition)
    [cards this]
  ?.  ?=([%timeout @ ~] wire)  (on-arvo:def wire sign-arvo)
  ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
  =/  request=(unit @uv)  (slaw %uv i.t.wire)
  ?~  request  `this
  ?.  (~(has by pending.state) u.request)  `this
  =/  ignored  (log bowl %debug [%request-timeout u.request])
  =/  transition=[cards=(list card) update=operation-update]
    (~(fail-request logic engine) u.request |)
  =^  cards  state
    (apply-operation-transition bowl transition)
  [cards this]
::
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
