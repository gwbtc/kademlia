::  Signed, leased content-record transport layered over %kademlia.
::
/-  *kademlia, *kademlia-agent, *content-routing, *content-routing-agent
/+  logic=content-routing-agent-logic, kad=kademlia, cr=content-routing
/+  default-agent, dbug, verb
|%
+$  card  card:agent:gall
--
::
%+  verb  |
%-  agent:dbug
=|  state=content-state
=>  |%
::
++  sign-digest
  |=  [=bowl:gall message=digest]
  ^-  record-signature
  =/  life=@ud
    .^(@ud %j /(scot %p our.bowl)/life/(scot %da now.bowl)/(scot %p our.bowl))
  =/  secret=ring
    .^(ring %j /(scot %p our.bowl)/vein/(scot %da now.bowl)/(scot %ud life))
  =/  cub  (nol:nu:crub:crypto secret)
  [life (sigh:as:cub message)]
::
++  fake-public
  |=  ship=@p
  ^-  pass
  =/  cub  (pit:nu:crub:crypto 512 ship)
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
    ~&  [%content-routing our.bowl %verify-no-public ship life.sig]
    |
  ?.  =(1 crypto-suite.u.public)
    ~&  [%content-routing our.bowl %verify-unsupported-suite ship crypto-suite.u.public]
    |
  =/  them  (com:nu:crub:crypto pass.u.public)
  =/  valid  (safe:as:them value.sig message)
  ?.  valid
    ~&  [%content-routing our.bowl %verify-failed ship life.sig]
    |
  &
::
++  send-message
  |=  [ship=@p message=content-message]
  ^-  card
  :*  %pass  /peer/(scot %p ship)
      %agent  [ship %content-routing]
      %poke  %content-routing-message  !>(message)
  ==
::
++  records-for
  |=  [=bowl:gall state=content-state request=query]
  ^-  records
  =/  verify=verifier
    |=  sample=[signer=node-id message=digest signature=*]
    (verify-record bowl sample)
  =/  engine  [our.bowl now.bowl src.bowl state verify]
  ?-  -.request
    %pointer
      =/  all=records  (~(values-for logic engine) key.request)
      (skim all |=(rec=record ?=(%pointer -.rec)))
    %providers
      =/  key=key  (provider-key:cr content.request)
      =/  all=records  (~(values-for logic engine) key)
      (scag max-providers.config.state (skim all |=(rec=record ?=(%provider -.rec))))
  ==
::
++  operation-notice-card
  |=  $:  our=@p
          id=operation-id
          callback=operation-callback
          result=operation-result
      ==
  ^-  card
  =/  notice=operation-notice  [reply-path.callback result]
  :*  %pass  /callback/(scot %uv id)
      %agent  [our recipient.callback]
      %poke  %content-routing-result  !>(notice)
  ==
::
++  new-operation-notices
  |=  $:  our=@p
          old=(map operation-id operation-result)
          new=(map operation-id operation-result)
          callbacks=(map operation-id operation-callback)
      ==
  ^-  [(list card) (map operation-id operation-callback)]
  =/  entries=(list [operation-id operation-result])  ~(tap by new)
  =/  cards=(list card)  ~
  |-
  ?~  entries  [(flop cards) callbacks]
  =/  id=operation-id  -.i.entries
  =/  result=operation-result  +.i.entries
  ?:  (~(has by old) id)
    $(entries t.entries)
  =/  callback=(unit operation-callback)  (~(get by callbacks) id)
  ?~  callback
    $(entries t.entries)
  =/  card=card  (operation-notice-card our id u.callback result)
  $(entries t.entries, cards [card cards], callbacks (~(del by callbacks) id))
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
  ~&  [%content-routing our.bowl %init]
  =.  state  ~(init logic engine)
  [[~(refresh-card logic engine) ~] this]
::
++  on-save  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =.  state  !<(content-state old)
  [[~(refresh-card logic engine) ~] this]
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %content-routing-command
    ?>  =(src.bowl our.bowl)
    =/  command=content-command  !<(content-command vase)
    ?-  -.command
      %publish-pointer
        ?>  (~(valid-id logic engine) id.command)
        ?>  (target-valid:cr target.command)
        =/  old=(map operation-id operation-result)  completed.state
        =/  publisher=node-id  ~(self-id logic engine)
        =/  key=key  (pointer-key:cr namespace.command publisher name.command)
        =/  body=pointer-body
          [namespace.command key publisher revision.command expires.command target.command]
        =/  rec=record  [%pointer body (sign-digest bowl (pointer-message:cr body))]
        =^  cards  state  (~(start-publish logic engine) id.command rec)
        =^  notices  callbacks.state
          (new-operation-notices our.bowl old completed.state callbacks.state)
        [(weld notices cards) this]
      %publish-provider
        ?>  (~(valid-id logic engine) id.command)
        ?>  (digest-valid:cr content.command)
        ?>  (locators-valid:cr locations.command)
        =/  old=(map operation-id operation-result)  completed.state
        =/  body=provider-body
          [content.command ~(self-id logic engine) revision.command expires.command locations.command]
        =/  rec=record  [%provider body (sign-digest bowl (provider-message:cr body))]
        =^  cards  state  (~(start-publish logic engine) id.command rec)
        =^  notices  callbacks.state
          (new-operation-notices our.bowl old completed.state callbacks.state)
        [(weld notices cards) this]
      %find-pointer
        ?>  (~(valid-id logic engine) id.command)
        ?>  (identity-valid:cr publisher.command)
        =/  old=(map operation-id operation-result)  completed.state
        =^  cards  state
          %+  ~(start-find-pointer logic engine)
            id.command
          [namespace.command publisher.command name.command]
        =^  notices  callbacks.state
          (new-operation-notices our.bowl old completed.state callbacks.state)
        [(weld notices cards) this]
      %find-providers
        ?>  (~(valid-id logic engine) id.command)
        ?>  (digest-valid:cr content.command)
        =/  old=(map operation-id operation-result)  completed.state
        =^  cards  state  (~(start-find-providers logic engine) id.command content.command)
        =^  notices  callbacks.state
          (new-operation-notices our.bowl old completed.state callbacks.state)
        [(weld notices cards) this]
      %observe
        ?>  (~(valid-id logic engine) id.command)
        =/  callback=operation-callback
          [recipient.command reply-path.command]
        =/  result=(unit operation-result)
          (~(get by completed.state) id.command)
        ?^  result
          [[(operation-notice-card our.bowl id.command callback u.result) ~] this]
        ?>  !(~(has by callbacks.state) id.command)
        =.  callbacks.state
          (~(put by callbacks.state) id.command callback)
        `this
      %forget
        ?>  (~(valid-id logic engine) id.command)
        =.  state  (~(forget logic engine) id.command)
        =.  callbacks.state  (~(del by callbacks.state) id.command)
        `this
      %set-config
        =.  state  (~(set-config logic engine) value.command)
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
    =/  old=(map operation-id operation-result)  completed.state
    =^  cards  state
      (~(receive-lookup logic engine) u.id contacts.result.notice)
    =^  notices  callbacks.state
      (new-operation-notices our.bowl old completed.state callbacks.state)
    [(weld notices cards) this]
  ::
      %content-routing-message
    =/  message=content-message  !<(content-message vase)
    ?.  =(version.message %content-routing-v1)  `this
    ?-  -.message
      %store
        ?.  (~(valid-id logic engine) id.message)  `this
        =/  decoded=(unit record)  (~(unpack-record logic engine) payload.message)
        ?~  decoded  `this
        =/  stored=[store-status content-state]  (~(put-replica logic engine) u.decoded)
        =.  state  +.stored
        ~&  [%content-routing our.bowl %store src.bowl id.message -.stored]
        =/  response=content-message  [%stored %content-routing-v1 id.message -.stored]
        [[(send-message src.bowl response) ~] this]
      %find-records
        ?.  (~(valid-id logic engine) id.message)  `this
        ?.  (~(valid-query logic engine) request.message)  `this
        =/  values=records  (records-for bowl state request.message)
        =/  packed=[count=@ud payload=@]  (~(pack-records logic engine) values)
        ~&  [%content-routing our.bowl %find-records src.bowl id.message request.message count.packed]
        =/  response=content-message
          [%records %content-routing-v1 id.message count.packed payload.packed]
        [[(send-message src.bowl response) ~] this]
      %stored
        ?.  (~(response-expected logic engine) id.message %.n)  `this
        ~&  [%content-routing our.bowl %stored src.bowl id.message status.message]
        =/  old=(map operation-id operation-result)  completed.state
        =^  cards  state  (~(receive-stored logic engine) id.message status.message)
        =^  notices  callbacks.state
          (new-operation-notices our.bowl old completed.state callbacks.state)
        [(weld notices cards) this]
      %records
        ?.  (~(response-expected logic engine) id.message %.y)  `this
        =/  decoded=(unit records)
          (~(unpack-records logic engine) count.message payload.message)
        =/  old=(map operation-id operation-result)  completed.state
        ?~  decoded
          =^  cards  state  (~(fail-request logic engine) id.message &)
          =^  notices  callbacks.state
            (new-operation-notices our.bowl old completed.state callbacks.state)
          [(weld notices cards) this]
        ~&  [%content-routing our.bowl %records src.bowl id.message count.message]
        =^  cards  state  (~(receive-records logic engine) id.message u.decoded)
        =^  notices  callbacks.state
          (new-operation-notices our.bowl old completed.state callbacks.state)
        [(weld notices cards) this]
    ==
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+    path  (on-peek:def path)
      [%x ~]             [~ ~]
      [%x %settings ~]   ``noun+!>(config.state)
      [%x %operation ~]  [~ ~]
      [%x %operation @ ~]
    =/  id=(unit @uv)  (slaw %uv i.t.t.path)
    ?~  id  ~
    ?.  (~(valid-id logic engine) u.id)  ~
    =/  view=(unit operation-view)  (~(get-operation logic engine) u.id)
    ?~  view  ~
    ``noun+!>(u.view)
  ::
      [%x %records @ ~]
    =/  key=(unit @ux)  (slaw %ux i.t.t.path)
    ?~  key  ~
    =/  values=records  (~(values-for logic engine) u.key)
    ``noun+!>(values)
  ::
      [%x %pointer @ ~]
    =/  key=(unit @ux)  (slaw %ux i.t.t.path)
    ?~  key  ~
    =/  values=records  (~(values-for logic engine) u.key)
    ``noun+!>((skim values |=(rec=record ?=(%pointer -.rec))))
  ::
      [%x %providers @ ~]
    =/  parsed=(unit @uv)  (slaw %uv i.t.t.path)
    ?~  parsed  ~
    =/  content=digest  u.parsed
    ``noun+!>((records-for bowl state [%providers content]))
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?.  ?=([%request @ ~] wire)  (on-agent:def wire sign)
  ?.  ?=(%poke-ack -.sign)  (on-agent:def wire sign)
  ?~  p.sign  `this
  =/  request=(unit @uv)  (slaw %uv i.t.wire)
  ?~  request  `this
  =/  old=(map operation-id operation-result)  completed.state
  =^  cards  state  (~(fail-request logic engine) u.request &)
  =^  notices  callbacks.state
    (new-operation-notices our.bowl old completed.state callbacks.state)
  [(weld notices cards) this]
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?:  =(/refresh wire)
    ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
    =^  cards  state  ~(refresh-origins logic engine)
    [cards this]
  ?.  ?=([%timeout @ ~] wire)  (on-arvo:def wire sign-arvo)
  ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
  =/  request=(unit @uv)  (slaw %uv i.t.wire)
  ?~  request  `this
  ?.  (~(has by pending.state) u.request)  `this
  =/  old=(map operation-id operation-result)  completed.state
  =^  cards  state  (~(fail-request logic engine) u.request |)
  =^  notices  callbacks.state
    (new-operation-notices our.bowl old completed.state callbacks.state)
  [(weld notices cards) this]
::
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
