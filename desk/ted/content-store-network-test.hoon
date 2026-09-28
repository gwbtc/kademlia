::  End-to-end unified content publication and retrieval across Aqua ships.
::
/-  spider, *kademlia-agent, *content-routing-agent
/-  cda=content-discovery-agent, *content-store, *content-store-test
/+  *ph-io, cr=content-routing
=,  strand=strand:spider
=/  content-cfg=content-config
  [1 1 2 ~s10 ~d1 ~h12 2 65.536 64 10.000]
=/  discovery-cfg=discovery-config:cda
  [1 1 2 ~s10 ~d1 ~h12 2 65.536 64 8 10.000]
=/  store-cfg=content-store-config  [~s10 ~d1 1.048.576]
^-  thread:spider
|=  argument=vase
=/  m  (strand ,vase)
%+  (set-timeout ,vase)  ~m10
|^
;<  ~  bind:m  start-simple
;<  ~  bind:m  (init-ship ~bud &)
;<  ~  bind:m  (init-ship ~wes &)
;<  ~  bind:m  configure-network
;<  ~  bind:m  (send-hi ~bud ~wes)
=/  value=(cask)  [%noun 42]
=/  content=digest  (digest-cask:cr value)
=/  name=path  ~[%packages %kademlia %latest]
=/  options=publication-options
  :*  `[namespace=%example name=name revision=[%auto ~] lifetime=`~h6]
      `[topic=~[%software %urbit] format=%content-store-test-v1 entries=1 revision=1]
  ==
::
::  One facade operation publishes the exact remote-scry page, provider
::  announcement, mutable pointer, and topic advertisement from ~wes.
::
;<  ~  bind:m
  %+  start-operation  ~wes
  :*  0v1
      [%put content 1 & `1 &]
      [%put 0v1 value options `~h6]
  ==
;<  ~  bind:m  (await-operation ~wes 0v1)
::
::  Pinning from ~bud proves provider discovery, exact-revision remote scry,
::  local page publication, and a second provider announcement in one
::  operation.  The subsequent digest read is local; the name read proves
::  pointer resolution, and search proves topic browsing.
::
;<  ~  bind:m
  %+  start-operation  ~bud
  :*  0v1
      [%pin content 1 &]
      [%pin 0v1 content `~h2]
  ==
;<  ~  bind:m  (await-operation ~bud 0v1)
;<  ~  bind:m
  (start-operation ~bud 0v2 [%get content value] [%get 0v2 [%content content]])
;<  ~  bind:m  (await-operation ~bud 0v2)
;<  ~  bind:m
  %+  start-operation  ~bud
  :*  0v3
      [%get content value]
      [%get 0v3 [%name ~wes %example name]]
  ==
;<  ~  bind:m  (await-operation ~bud 0v3)
;<  ~  bind:m
  %+  start-operation  ~bud
  :*  0v4
      [%search ~[%software %urbit] 1 ~]
      [%search 0v4 ~[%software %urbit]]
  ==
;<  ~  bind:m  (await-operation ~bud 0v4)
;<  ~  bind:m
  (start-operation ~bud 0v5 [%unpin content] [%unpin 0v5 content])
;<  ~  bind:m  (await-operation ~bud 0v5)
;<  ~  bind:m  end
(pure:m !>(~))
::
++  configure-network
  =/  m  (strand ,~)
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-seeds ~[~wes]])
  ;<  ~  bind:m  (poke-kademlia ~bud [%set-request-timeout ~s10])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-seeds ~[~bud]])
  ;<  ~  bind:m  (poke-kademlia ~wes [%set-request-timeout ~s10])
  ;<  ~  bind:m  (poke-content ~bud [%set-config content-cfg])
  ;<  ~  bind:m  (poke-content ~wes [%set-config content-cfg])
  ;<  ~  bind:m  (poke-discovery ~bud [%set-config discovery-cfg])
  ;<  ~  bind:m  (poke-discovery ~wes [%set-config discovery-cfg])
  ;<  ~  bind:m  (poke-store ~bud [%set-config store-cfg])
  (poke-store ~wes [%set-config store-cfg])
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
++  poke-discovery
  |=  [who=@p command=discovery-command:cda]
  =/  m  (strand ,~)
  (dojo who ":content-discovery &content-discovery-command {<command>}")
::
++  poke-store
  |=  [who=@p command=content-store-command]
  =/  m  (strand ,~)
  (dojo who ":content-store &content-store-command {<command>}")
::
++  poke-observer
  |=  [who=@p command=content-store-observer-command]
  =/  m  (strand ,~)
  (poke-app who %content-store-test-observer %noun command)
::
++  start-operation
  |=  $:  who=@p
          id=content-store-id
          expected=content-store-expectation
          command=content-store-command
      ==
  =/  m  (strand ,~)
  (poke-observer who [%start id expected command])
::
++  await-operation
  |=  [who=@p id=content-store-id]
  =/  m  (strand ,~)
  =/  pax=path  /operation/(scot %uv id)
  (wait-for-output who "content-store-test-observer {(spud pax)} complete")
--
