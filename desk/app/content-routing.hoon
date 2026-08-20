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
    =/  ignored  (log bowl %debug [%record-verification-failed ship life.sig %no-public-key])
    |
  ?.  =(1 crypto-suite.u.public)
    =/  ignored
      (log bowl %debug [%record-verification-failed ship life.sig %unsupported-suite])
    |
  =/  them  (com:nu:crub:crypto pass.u.public)
  =/  valid  (safe:as:them value.sig message)
  ?.  valid
    =/  ignored  (log bowl %debug [%record-verification-failed ship life.sig %bad-signature])
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
++  operation-completion-notices
  |=  $:  =bowl:gall
          completions=(list operation-completion)
          callbacks=(map operation-id operation-callback)
      ==
  ^-  [(list card) (map operation-id operation-callback)]
  =/  cards=(list card)  ~
  |-
  ?~  completions  [(flop cards) callbacks]
  =/  completion=operation-completion  i.completions
  =/  ignored
    (log bowl %info [%operation-complete id.completion -.result.completion])
  =/  id=operation-id  id.completion
  =/  callback=(unit operation-callback)  (~(get by callbacks) id)
  ?~  callback  $(completions t.completions)
  =/  card=card
    (operation-notice-card our.bowl id u.callback result.completion)
  %=  $
    completions  t.completions
    callbacks    (~(del by callbacks) id)
    cards        [card cards]
  ==
::
++  apply-operation-transition
  |=  $:  =bowl:gall
          transition=[cards=(list card) update=operation-update]
      ==
  ^-  [(list card) content-state]
  =/  noticed=[(list card) (map operation-id operation-callback)]
    %+  operation-completion-notices  bowl
    [completions.update.transition callbacks.state.update.transition]
  =/  out=content-state  state.update.transition
  =.  callbacks.out  +.noticed
  [(weld -.noticed cards.transition) out]
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
++  on-save  !>(`content-saved-state`[state verbosity])
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  saved=content-saved-state  !<(content-saved-state old)
  =.  state  state.saved
  =.  verbosity  verbosity.saved
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
        =/  publisher=node-id  ~(self-id logic engine)
        =/  key=key  (pointer-key:cr namespace.command publisher name.command)
        =/  body=pointer-body
          [namespace.command key publisher revision.command expires.command target.command]
        =/  rec=record  [%pointer body (sign-digest bowl (pointer-message:cr body))]
        =/  ignored  (log bowl %info [%operation-start id.command %publish-pointer key])
        =^  cards  state  (~(start-publish logic engine) id.command rec)
        [cards this]
      %publish-provider
        ?>  (~(valid-id logic engine) id.command)
        ?>  (digest-valid:cr content.command)
        ?>  (locators-valid:cr locations.command)
        =/  body=provider-body
          [content.command ~(self-id logic engine) revision.command expires.command locations.command]
        =/  rec=record  [%provider body (sign-digest bowl (provider-message:cr body))]
        =/  ignored  (log bowl %info [%operation-start id.command %publish-provider content.command])
        =^  cards  state  (~(start-publish logic engine) id.command rec)
        [cards this]
      %find-pointer
        ?>  (~(valid-id logic engine) id.command)
        ?>  (identity-valid:cr publisher.command)
        =/  key=key  (pointer-key:cr namespace.command publisher.command name.command)
        =/  ignored  (log bowl %info [%operation-start id.command %find-pointer key])
        =^  cards  state
          %+  ~(start-find-pointer logic engine)
            id.command
          [namespace.command publisher.command name.command]
        [cards this]
      %find-providers
        ?>  (~(valid-id logic engine) id.command)
        ?>  (digest-valid:cr content.command)
        =/  ignored  (log bowl %info [%operation-start id.command %find-providers content.command])
        =^  cards  state  (~(start-find-providers logic engine) id.command content.command)
        [cards this]
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
      %content-routing-message
    =/  message=content-message  !<(content-message vase)
    ?.  =(version.message %content-routing-v1)  `this
    ?-  -.message
      %store
        ?.  (~(valid-id logic engine) id.message)  `this
        =/  decoded=(unit sized-record)  (~(unpack-record logic engine) payload.message)
        ?~  decoded  `this
        =/  stored=[store-status content-state]
          (~(put-replica-sized logic engine) u.decoded)
        =.  state  +.stored
        =/  ignored  (log bowl %debug [%peer-store src.bowl id.message -.stored])
        =/  response=content-message  [%stored %content-routing-v1 id.message -.stored]
        [[(send-message src.bowl response) ~] this]
      %find-records
        ?.  (~(valid-id logic engine) id.message)  `this
        ?.  (~(valid-query logic engine) request.message)  `this
        =/  values=records  (records-for bowl state request.message)
        =/  packed=[count=@ud payload=@]  (~(pack-records logic engine) values)
        =/  ignored
          (log bowl %debug [%peer-find-records src.bowl id.message -.request.message count.packed])
        =/  response=content-message
          [%records %content-routing-v1 id.message count.packed payload.packed]
        [[(send-message src.bowl response) ~] this]
      %stored
        ?.  (~(response-expected logic engine) id.message %.n)  `this
        =/  ignored  (log bowl %debug [%peer-stored src.bowl id.message status.message])
        =/  transition=[cards=(list card) update=operation-update]
          (~(receive-stored logic engine) id.message status.message)
        =^  cards  state
          (apply-operation-transition bowl transition)
        [cards this]
      %records
        ?.  (~(response-expected logic engine) id.message %.y)  `this
        =/  decoded=(unit sized-records)
          (~(unpack-records logic engine) count.message payload.message)
        ?~  decoded
          =/  transition=[cards=(list card) update=operation-update]
            (~(fail-request logic engine) id.message &)
          =^  cards  state
            (apply-operation-transition bowl transition)
          [cards this]
        =/  ignored  (log bowl %debug [%peer-records src.bowl id.message count.message])
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
      [%x %verbosity ~]  ``noun+!>(verbosity)
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
  =/  transition=[cards=(list card) update=operation-update]
    (~(fail-request logic engine) u.request &)
  =/  ignored  (log bowl %debug [%request-poke-failed u.request])
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
