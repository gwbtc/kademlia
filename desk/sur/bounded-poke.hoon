::  Persistent state for bounding remote Gall pokes per peer.
::
|%
+$  delivery-id  @ud
+$  delivery-context
  $%  [%request id=@uv]
      [%response id=@uv]
  ==
::
::  delivery-note: the one note a delivery passes, a poke to an agent.
::  state must not hold $note:agent:gall: its type covers every vane
::  task, so a kernel update would change the type of the saved state.
+$  delivery-note  [%agent [=ship name=term] %poke =cage]
+$  queued-delivery
  $:  id=delivery-id
      peer=@p
      deadline=@da
      context=delivery-context
      note=delivery-note
  ==
+$  active-delivery
  [id=delivery-id context=delivery-context]
+$  peer-delivery
  $:  active=(unit active-delivery)
      responses=(list queued-delivery)
      requests=(list queued-delivery)
      wake=(unit @da)
  ==
+$  delivery-state
  $:  next-id=delivery-id
      peers=(map @p peer-delivery)
      expired-total=@ud
      overflow-dropped=@ud
  ==
::
::  stale-delivery-state: any $delivery-state, read without its queues.
+$  stale-delivery-state
  $:  next-id=delivery-id
      peers=(map @p [active=(unit active-delivery) *])
      expired-total=@ud
      overflow-dropped=@ud
  ==
+$  delivery-summary
  $:  peers=@ud
      active=@ud
      queued-responses=@ud
      queued-requests=@ud
      expired=@ud
      overflow-dropped=@ud
  ==
+$  delivery-ack
  [context=delivery-context error=(unit tang)]
+$  delivery-update
  $:  cards=(list card:agent:gall)
      expired=(list delivery-context)
      acked=(unit delivery-ack)
      state=delivery-state
  ==
--
