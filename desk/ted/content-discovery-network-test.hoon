::  End-to-end hierarchical topic discovery across two Aqua virtual ships.
::
/-  spider, *kademlia, *kademlia-agent, *content-discovery-test
/-  *content-routing, *content-discovery, *content-discovery-agent
/+  *ph-io
=,  strand=strand:spider
=/  discovery-cfg=discovery-config
  [2 1 4 ~h1 ~d1 ~h12 2 65.536 64 8 10.000]
^-  thread:spider
|=  argument=vase
|^
=/  m  (strand ,vase)
;<  ~  bind:m  start-simple
;<  ~  bind:m  (init-ship ~bud &)
;<  ~  bind:m  (init-ship ~wes &)
;<  ~  bind:m  configure-network
;<  ~  bind:m  (send-hi ~bud ~wes)
::
::  Advertising a leaf automatically publishes its catalog record and the
::  edges visible at each nonempty strict prefix.  Replication two puts every
::  record on both ships; the browse operations below originate on ~bud.
::
;<  ~  bind:m
  %+  start-discovery  ~wes
  :*  0v1
      [%advertised 3 2]
      [%advertise 0v1 ~[%software %urbit %hoon] %demo 0v42 2 1 ~2100.1.1]
  ==
;<  ~  bind:m  (await-operation ~wes 0v1)
;<  ~  bind:m
  (start-discovery ~bud 0v1 [%topic 0 ~[%urbit]] [%browse 0v1 ~[%software]])
;<  ~  bind:m  (await-operation ~bud 0v1)
;<  ~  bind:m
  (start-discovery ~bud 0v2 [%topic 0 ~[%hoon]] [%browse 0v2 ~[%software %urbit]])
;<  ~  bind:m  (await-operation ~bud 0v2)
;<  ~  bind:m
  (start-discovery ~bud 0v3 [%topic 1 ~] [%browse 0v3 ~[%software %urbit %hoon]])
;<  ~  bind:m  (await-operation ~bud 0v3)
;<  ~  bind:m  end
(pure:m !>(~))
::
++  configure-network
  =/  m  (strand ,~)
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-verbosity %debug])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-verbosity %debug])
  ;<  ~  bind:m  (poke-discovery ~bud [%set-verbosity %debug])
  ;<  ~  bind:m  (poke-discovery ~wes [%set-verbosity %debug])
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-seeds ~[~wes]])
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-request-timeout ~h1])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-seeds ~[~bud]])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-request-timeout ~h1])
  ;<  ~  bind:m  (poke-discovery ~bud [%set-config discovery-cfg])
  (poke-discovery ~wes [%set-config discovery-cfg])
::
++  poke-kademlia
  |=  [who=@p =command]
  =/  m  (strand ,~)
  (dojo who ":kademlia-example &kademlia-command {<command>}")
::
++  poke-discovery
  |=  [who=@p command=discovery-command]
  =/  m  (strand ,~)
  (dojo who ":kademlia-example &content-discovery-command {<command>}")
::
++  poke-observer
  |=  [who=@p command=discovery-observer-command]
  =/  m  (strand ,~)
  (poke-app who %content-discovery-test-observer %noun command)
::
++  start-discovery
  |=  $:  who=@p
          id=operation-id
          expected=discovery-expectation
          command=discovery-command
      ==
  =/  m  (strand ,~)
  =/  reply-path=path  /operation/(scot %uv id)
  ;<  ~  bind:m
    (poke-observer who [%expect id expected])
  ;<  ~  bind:m
    (poke-discovery who [%observe id %content-discovery-test-observer reply-path])
  (poke-discovery who command)
::
++  await-operation
  |=  [who=@p id=operation-id]
  =/  m  (strand ,~)
  =/  pax=path  /operation/(scot %uv id)
  (wait-for-output who "content-discovery-test-observer {(spud pax)} complete")
--
