::  Persistent state for bounding remote Gall pokes per peer.
::
|%
+$  delivery-id  @ud
+$  delivery-context
  $%  [%request id=@uv]
      [%response id=@uv]
  ==
+$  queued-delivery
  $:  id=delivery-id
      peer=@p
      deadline=@da
      context=delivery-context
      note=note:agent:gall
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
