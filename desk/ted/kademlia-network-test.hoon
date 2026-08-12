::  End-to-end Kademlia discovery across an Aqua virtual fleet.
::
/-  spider, aquarium, *kademlia, *kademlia-agent
/-  *content-routing, *content-routing-agent
/+  *ph-io, util=ph-util, kad=kademlia, cr=content-routing
=,  strand=strand:spider
=/  cfg=config  [20 20 3 12 %kademlia-urbit-v1]
=/  test-timeout=@dr  ~m3
=/  poll-interval=@dr  ~s5
=/  max-polls=@ud  60
^-  thread:spider
|=  argument=vase
|^
=/  m  (strand ,vase)
;<  ~  bind:m  start-simple
;<  ~  bind:m  (init-ship ~bud &)
;<  ~  bind:m  (init-ship ~dev &)
;<  ~  bind:m  (init-ship ~marbud &)
;<  ~  bind:m  (init-ship ~mardev &)
;<  ~  bind:m  (disable-ota ~bud)
;<  ~  bind:m  (disable-ota ~dev)
;<  ~  bind:m  (disable-ota ~marbud)
;<  ~  bind:m  (disable-ota ~mardev)
::
::  Production RPCs allow five minutes. Aqua can take about two minutes to
::  retransmit the first Ames packet on a fresh route, so retain enough margin
::  for that without making a failed test wait the full production interval.
::
;<  ~  bind:m  (set-timeout ~bud)
;<  ~  bind:m  (set-timeout ~dev)
;<  ~  bind:m  (set-timeout ~marbud)
;<  ~  bind:m  (set-timeout ~mardev)
;<  ~  bind:m  (set-content-timeout ~bud)
;<  ~  bind:m  (set-content-timeout ~mardev)
::
::  Establish the Ames links used by the topology before testing Kademlia.
::  Otherwise the first Kademlia request can spend its entire timeout waiting
::  for Ames's initial neighbor handshake.
::
;<  ~  bind:m  (send-hi ~dev ~marbud)
;<  ~  bind:m  (send-hi ~marbud ~mardev)
;<  ~  bind:m  (send-hi ~bud ~dev)
::
::  Warm ~dev -> ~marbud before ~marbud learns ~mardev.  This ensures ~dev
::  can introduce ~marbud, but cannot shortcut directly to ~mardev.
::
=/  marbud-id=node-id  (~(ship-to-node kad cfg) ~marbud)
=/  mardev-id=node-id  (~(ship-to-node kad cfg) ~mardev)
;<  ~  bind:m  (set-seeds ~dev ~[~marbud])
;<  ~  bind:m  (start-lookup ~dev 0v1 marbud-id)
;<  ~  bind:m  (wait-for-lookup ~dev 0v1 marbud-id ~[marbud-id])
;<  ~  bind:m  (set-seeds ~marbud ~[~mardev])
;<  ~  bind:m  (start-lookup ~marbud 0v1 mardev-id)
;<  ~  bind:m  (wait-for-lookup ~marbud 0v1 mardev-id ~[mardev-id])
::
::  ~bud initially knows only ~dev.  Reaching ~mardev therefore requires the
::  actual iterative path ~bud -> ~dev -> ~marbud -> ~mardev over Ames.
::
=/  dev-id=node-id  (~(ship-to-node kad cfg) ~dev)
;<  ~  bind:m  (set-seeds ~bud ~[~dev])
;<  ~  bind:m  (start-lookup ~bud 0v1 mardev-id)
;<  ~  bind:m
  (wait-for-lookup ~bud 0v1 mardev-id ~[dev-id marbud-id mardev-id])
;<  routing=table  bind:m  (read-table ~bud)
=/  learned=(list node-id)
  (turn (~(contacts kad cfg) routing) |=(con=contact id.con))
?>  (all-present ~[dev-id marbud-id mardev-id] learned)
::
::  Publish a signed provider record from the far end of the discovered
::  topology, then find it from ~bud through the separate transport agent.
::
=/  content=digest  (digest-cask:cr `(cask)`[%noun 42])
=/  location=locator  [%scry [~mardev /example/content]]
;<  ~  bind:m
  (poke-content ~mardev [%publish-provider 0v1 content 1 ~2100.1.1 [location ~]])
;<  ~  bind:m  (wait-for-publication ~mardev 0v1)
;<  ~  bind:m  (poke-content ~bud [%find-providers 0v1 content])
;<  ~  bind:m  (wait-for-provider ~bud 0v1 mardev-id content)
;<  ~  bind:m  end
(pure:m !>(~))
::
++  set-seeds
  |=  [who=@p ships=(list @p)]
  =/  m  (strand ,~)
  (poke-kademlia who [%set-seeds ships])
::
++  disable-ota
  |=  who=@p
  =/  m  (strand ,~)
  (dojo who "|ota %disable")
::
++  set-timeout
  |=  who=@p
  =/  m  (strand ,~)
  (poke-kademlia who [%set-request-timeout test-timeout])
::
++  set-content-timeout
  |=  who=@p
  =/  m  (strand ,~)
  =/  value=content-config
    [20 3 test-timeout ~d1 ~h12 65.536 64 10.000]
  (poke-content who [%set-config value])
::
++  start-lookup
  |=  [who=@p id=lookup-id target=node-id]
  =/  m  (strand ,~)
  (poke-kademlia who [%find id target])
::
::  Inject a typed Gall poke directly.  Going through virtual Dojo's &mark
::  syntax requires the custom mark to be installed in Dojo's source desk.
::
++  poke-kademlia
  |=  [who=@p =command]
  =/  m  (strand ,~)
  =/  event=aqua-event:aquarium
    :+  %event  who
    :*  /g/aqua/kademlia  %deal  [who who /]
        %kademlia  %poke  [%kademlia-command !>(command)]
    ==
  (send-events event ~)
::
++  poke-content
  |=  [who=@p command=content-command]
  =/  m  (strand ,~)
  =/  event=aqua-event:aquarium
    :+  %event  who
    :*  /g/aqua/content-routing  %deal  [who who /]
        %content-routing  %poke  [%content-routing-command !>(command)]
    ==
  (send-events event ~)
::
++  read-lookup
  |=  [who=@p id=lookup-id]
  =/  m  (strand (unit lookup-view))
  ;<  bol=bowl:spider  bind:m  get-bowl
  =/  pax=path
    /i/(scot %p who)/gx/(scot %p who)/kademlia/(scot %da now.bol)/lookup/(scot %uv id)/noun/noun
  =/  result=(unit lookup-view)
    (scry-aqua:util (unit lookup-view) our.bol now.bol pax)
  (pure:m result)
::
++  read-table
  |=  who=@p
  =/  m  (strand ,table)
  ;<  bol=bowl:spider  bind:m  get-bowl
  =/  pax=path
    /i/(scot %p who)/gx/(scot %p who)/kademlia/(scot %da now.bol)/table/noun/noun
  =/  result=(unit table)
    (scry-aqua:util (unit table) our.bol now.bol pax)
  (pure:m (need result))
::
++  read-content-operation
  |=  [who=@p id=operation-id]
  =/  m  (strand (unit operation-view))
  ;<  bol=bowl:spider  bind:m  get-bowl
  =/  pax=path
    /i/(scot %p who)/gx/(scot %p who)/content-routing/(scot %da now.bol)/operation/(scot %uv id)/noun/noun
  =/  result=(unit operation-view)
    (scry-aqua:util (unit operation-view) our.bol now.bol pax)
  (pure:m result)
::
++  wait-for-lookup
  |=  [who=@p id=lookup-id target=node-id expected=(list node-id)]
  =/  m  (strand ,~)
  =/  attempts=@ud  max-polls
  |-
  =*  loop  $
  ;<  ~     bind:m  (sleep poll-interval)
  ;<  result=(unit lookup-view)  bind:m  (read-lookup who id)
  ?~  result
    ~_  leaf+"lookup {<id>} on {<who>} never became visible"
    ?>  (gth attempts 1)
    loop(attempts (dec attempts))
  =/  view=lookup-view  u.result
  ?:  ?=(%complete -.view)
    ?>  =(target target.result.view)
    ?>  (all-present expected contacts.result.view)
    (pure:m ~)
  ~_  leaf+"lookup {<id>} on {<who>} did not complete"
  ?>  (gth attempts 1)
  loop(attempts (dec attempts))
::
++  wait-for-publication
  |=  [who=@p id=operation-id]
  =/  m  (strand ,~)
  =/  attempts=@ud  max-polls
  |-
  =*  loop  $
  ;<  ~  bind:m  (sleep poll-interval)
  ;<  result=(unit operation-view)  bind:m  (read-content-operation who id)
  ?~  result
    ~_  leaf+"publication {<id>} on {<who>} never became visible"
    ?>  (gth attempts 1)
    loop(attempts (dec attempts))
  =/  view=operation-view  u.result
  ?:  ?=(%complete -.view)
    ~&  [%kademlia-aqua-publication who id value.view]
    ?>  ?=(%published -.value.view)
    ::  The publisher's local origin is always accepted.  Require at least
    ::  one other node so the subsequent lookup tests replicated transport.
    ?>  (gth (lent ~(tap in accepted.value.value.view)) 1)
    (pure:m ~)
  ~_  leaf+"publication {<id>} on {<who>} did not complete"
  ?>  (gth attempts 1)
  loop(attempts (dec attempts))
::
++  wait-for-provider
  |=  [who=@p id=operation-id expected=node-id content=digest]
  =/  m  (strand ,~)
  =/  attempts=@ud  max-polls
  |-
  =*  loop  $
  ;<  ~  bind:m  (sleep poll-interval)
  ;<  result=(unit operation-view)  bind:m  (read-content-operation who id)
  ?~  result
    ~_  leaf+"provider lookup {<id>} on {<who>} never became visible"
    ?>  (gth attempts 1)
    loop(attempts (dec attempts))
  =/  view=operation-view  u.result
  ?:  ?=(%complete -.view)
    ~&  [%kademlia-aqua-provider-query who id value.view]
    ?>  ?=(%providers -.value.view)
    =/  records=providers  records.selection.value.value.view
    ?>  %+  lien  records
        |=  record=provider
        ?&  =(content content.body.record)
            =(expected provider.body.record)
        ==
    (pure:m ~)
  ~_  leaf+"provider lookup {<id>} on {<who>} did not complete"
  ?>  (gth attempts 1)
  loop(attempts (dec attempts))
::
++  all-present
  |=  [expected=(list node-id) actual=(list node-id)]
  ^-  ?
  %+  levy  expected
  |=  id=node-id
  (lien actual |=(candidate=node-id =(id candidate)))
--
