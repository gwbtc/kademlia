::  Publish and retrieve one generated resource across two Aqua ships.
::
/-  spider, *kademlia-agent, *content-routing-agent, *kademlia-demo
/+  *ph-io, demo=kademlia-demo
=,  strand=strand:spider
=/  content-cfg=content-config  [1 1 2 ~s10 ~d1 ~h12 2 65.536 64 10.000]
^-  thread:spider
|=  argument=vase
|^
=/  m  (strand ,vase)
;<  ~  bind:m  start-simple
;<  ~  bind:m  (init-ship ~bud &)
;<  ~  bind:m  (init-ship ~wes &)
;<  ~  bind:m  (start-demo ~bud)
;<  ~  bind:m  (start-demo ~wes)
;<  ~  bind:m  configure-network
;<  ~  bind:m  (send-hi ~bud ~wes)
=/  resource=resource  (make-resource:demo 42 262.144 'application/octet-stream')
;<  ~  bind:m  (expect ~wes %create)
;<  ~  bind:m
  (poke-demo ~wes [%create %create 42 262.144 'application/octet-stream'])
;<  ~  bind:m  (await ~wes %create)
;<  ~  bind:m  (expect ~wes %publish)
;<  ~  bind:m  (poke-demo ~wes [%publish %publish content.resource %custom ~])
;<  ~  bind:m  (await ~wes %publish)
;<  ~  bind:m  (expect ~bud %fetch)
;<  ~  bind:m  (poke-demo ~bud [%fetch %fetch [%content content.resource]])
;<  ~  bind:m  (await ~bud %fetch)
=/  scry-resource
  (make-resource:demo 43 262.144 'application/octet-stream')
;<  ~  bind:m  (expect ~wes %create-scry)
;<  ~  bind:m
  (poke-demo ~wes [%create %create-scry 43 262.144 'application/octet-stream'])
;<  ~  bind:m  (await ~wes %create-scry)
;<  ~  bind:m  (expect ~wes %publish-scry)
;<  ~  bind:m
  (poke-demo ~wes [%publish %publish-scry content.scry-resource %scry ~])
;<  ~  bind:m  (await ~wes %publish-scry)
;<  ~  bind:m  (expect ~bud %fetch-scry)
;<  ~  bind:m
  (poke-demo ~bud [%fetch %fetch-scry [%content content.scry-resource]])
;<  ~  bind:m  (await ~bud %fetch-scry)
;<  ~  bind:m  end
(pure:m !>(~))
::
++  start-demo
  |=  who=@p
  =/  m  (strand ,~)
  (dojo who "|start %kademlia-demo %kademlia")
::
++  configure-network
  =/  m  (strand ,~)
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-seeds ~[~wes]])
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-request-timeout ~s10])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-seeds ~[~bud]])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-request-timeout ~s10])
  ;<  ~  bind:m  (poke-content ~bud [%set-config content-cfg])
  (poke-content ~wes [%set-config content-cfg])
::
++  poke-kademlia
  |=  [who=@p command=command]
  =/  m  (strand ,~)
  (dojo who ":kademlia &kademlia-command {<command>}")
::
++  poke-content
  |=  [who=@p command=content-command]
  =/  m  (strand ,~)
  (dojo who ":content-routing &content-routing-command {<command>}")
::
++  poke-demo
  |=  [who=@p command=demo-command]
  =/  m  (strand ,~)
  (dojo who ":kademlia-demo &kademlia-demo-command {<command>}")
::
++  expect
  |=  [who=@p run=run-id]
  =/  m  (strand ,~)
  (poke-app who %kademlia-demo-test-observer %noun run)
::
++  await
  |=  [who=@p run=run-id]
  =/  m  (strand ,~)
  (wait-for-output who "kademlia-demo-test-observer {<run>} complete")
--
