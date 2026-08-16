::  End-to-end Kademlia discovery across an Aqua virtual fleet.
::
/-  spider, *kademlia, *kademlia-agent, *kademlia-test
/+  *ph-io, kad=kademlia
=,  strand=strand:spider
=/  cfg=config  [20 20 3 12 %kademlia-urbit-v1]
^-  thread:spider
|=  argument=vase
|^
=/  m  (strand ,vase)
;<  ~  bind:m  start-simple
;<  ~  bind:m  (init-ship ~bud &)
;<  ~  bind:m  (init-ship ~dev &)
;<  ~  bind:m  (init-ship ~wes &)
;<  ~  bind:m  configure-network
::
=/  wes-id=node-id  (~(ship-to-node kad cfg) ~wes)
::
::  Warm ~dev's route to ~wes before exposing ~dev to ~bud.
::
;<  ~  bind:m  (send-hi ~dev ~wes)
;<  ~  bind:m  (start-lookup ~dev 0v1 wes-id ~[wes-id])
;<  ~  bind:m  (wait-for-lookup ~dev 0v1)
::
::  ~bud initially knows only ~dev.  Reaching ~wes therefore requires the
::  iterative path ~bud -> ~dev -> ~wes over Ames.
::
=/  dev-id=node-id  (~(ship-to-node kad cfg) ~dev)
;<  ~  bind:m  (send-hi ~bud ~dev)
;<  ~  bind:m  (start-lookup ~bud 0v1 wes-id ~[dev-id wes-id])
;<  ~  bind:m  (wait-for-lookup ~bud 0v1)
;<  ~  bind:m  end
(pure:m !>(~))
::
++  configure-network
  =/  m  (strand ,~)
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-seeds ~[~dev]])
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-request-timeout ~h1])
  ;<  ~  bind:m  (poke-kademlia ~dev [%set-seeds ~[~wes]])
  ;<  ~  bind:m  (poke-kademlia ~dev [%set-request-timeout ~h1])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-seeds ~])
  (poke-kademlia ~wes [%set-request-timeout ~h1])
::
++  poke-kademlia
  |=  [who=@p =command]
  =/  m  (strand ,~)
  (dojo who ":kademlia &kademlia-command {<command>}")
::
++  poke-observer
  |=  [who=@p command=observer-command]
  =/  m  (strand ,~)
  (poke-app who %kademlia-test-observer %noun command)
::
++  start-lookup
  |=  [who=@p id=lookup-id target=node-id expected=(list node-id)]
  =/  m  (strand ,~)
  =/  pax=path  /lookup/(scot %uv id)
  ;<  ~  bind:m
    (poke-observer who [%expect-lookup id target expected])
  (poke-kademlia who [%find-for target %kademlia-test-observer pax])
::
++  wait-for-lookup
  |=  [who=@p id=lookup-id]
  =/  m  (strand ,~)
  =/  pax=path  /lookup/(scot %uv id)
  (wait-for-output who "kademlia-test-observer {(spud pax)} complete")
--
