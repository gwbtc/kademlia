::  End-to-end content-record transport across two Aqua virtual ships.
::
/-  spider, *kademlia, *kademlia-agent, *kademlia-test
/-  *content-routing, *content-routing-agent
/+  *ph-io, kad=kademlia, cr=content-routing
=,  strand=strand:spider
=/  cfg=config  [20 20 3 12 %kademlia-urbit-v1]
=/  content-cfg=content-config  [2 1 4 ~h1 ~d1 ~h12 2 65.536 64 10.000]
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
::  Both records are published by ~wes and replicated to ~bud.  The later
::  reads run from ~bud, proving that the result crossed Ames rather than being
::  satisfied solely from the publisher's origin store.
::
=/  wes-id=node-id  (~(ship-to-node kad cfg) ~wes)
=/  content=digest  (digest-cask:cr `(cask)`[%noun 42])
=/  location=locator  [%scry [~wes /example/content]]
=/  target=target  [%content content]
=/  name=path  ~[%packages %kademlia %latest]
;<  ~  bind:m
  (start-content ~wes 0v1 [%publication 2] [%publish-pointer 0v1 %example name 1 ~ target])
;<  ~  bind:m  (await-operation ~wes 0v1)
;<  ~  bind:m
  (start-content ~wes 0v2 [%publication 2] [%publish-provider 0v2 content 1 ~2100.1.1 [location ~]])
;<  ~  bind:m  (await-operation ~wes 0v2)
;<  ~  bind:m
  (start-content ~bud 0v1 [%pointer wes-id 1 target] [%find-pointer 0v1 %example wes-id name])
;<  ~  bind:m  (await-operation ~bud 0v1)
;<  ~  bind:m
  (start-content ~bud 0v2 [%provider wes-id content location] [%find-providers 0v2 content])
;<  ~  bind:m  (await-operation ~bud 0v2)
;<  ~  bind:m  end
(pure:m !>(~))
::
++  configure-network
  =/  m  (strand ,~)
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-verbosity %debug])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-verbosity %debug])
  ;<  ~  bind:m  (poke-content ~bud [%set-verbosity %debug])
  ;<  ~  bind:m  (poke-content ~wes [%set-verbosity %debug])
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-seeds ~[~wes]])
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-request-timeout ~h1])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-seeds ~[~bud]])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-request-timeout ~h1])
  ;<  ~  bind:m  (poke-content ~bud [%set-config content-cfg])
  (poke-content ~wes [%set-config content-cfg])
::
++  poke-kademlia
  |=  [who=@p =command]
  =/  m  (strand ,~)
  (dojo who ":kademlia &kademlia-command {<command>}")
::
++  poke-content
  |=  [who=@p command=content-command]
  =/  m  (strand ,~)
  (dojo who ":content-routing &content-routing-command {<command>}")
::
++  poke-observer
  |=  [who=@p command=observer-command]
  =/  m  (strand ,~)
  (poke-app who %kademlia-test-observer %noun command)
::
++  start-content
  |=  $:  who=@p
          id=operation-id
          expected=operation-expectation
          command=content-command
      ==
  =/  m  (strand ,~)
  =/  reply-path=path  /operation/(scot %uv id)
  ;<  ~  bind:m
    (poke-observer who [%expect-operation id expected])
  ;<  ~  bind:m
    (poke-content who [%observe id %kademlia-test-observer reply-path])
  (poke-content who command)
::
++  await-operation
  |=  [who=@p id=operation-id]
  =/  m  (strand ,~)
  =/  pax=path  /operation/(scot %uv id)
  (wait-for-output who "kademlia-test-observer {(spud pax)} complete")
--
