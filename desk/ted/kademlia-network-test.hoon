::  End-to-end Kademlia discovery across an Aqua virtual fleet.
::
/-  spider, aquarium, *kademlia, *kademlia-agent
/+  *ph-io, util=ph-util, kad=kademlia
=,  strand=strand:spider
=/  cfg=config  [20 20 3 12 %kademlia-urbit-v1]
^-  thread:spider
|=  argument=vase
|^
=/  m  (strand ,vase)
;<  ~  bind:m  start-simple
;<  ~  bind:m  (init-ship ~bud &)
;<  ~  bind:m  (init-ship ~dev &)
;<  ~  bind:m  (init-ship ~marbud &)
;<  ~  bind:m  (init-ship ~mardev &)
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
;<  ~  bind:m  end
(pure:m !>(~))
::
++  set-seeds
  |=  [who=@p ships=(list @p)]
  =/  m  (strand ,~)
  (poke-kademlia who [%set-seeds ships])
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
++  wait-for-lookup
  |=  [who=@p id=lookup-id target=node-id expected=(list node-id)]
  =/  m  (strand ,~)
  =/  attempts=@ud  90
  |-
  =*  loop  $
  ;<  ~     bind:m  (sleep ~s10)
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
++  all-present
  |=  [expected=(list node-id) actual=(list node-id)]
  ^-  ?
  %+  levy  expected
  |=  id=node-id
  (lien actual |=(candidate=node-id =(id candidate)))
--
