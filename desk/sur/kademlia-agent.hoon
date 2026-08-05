::  Gall command, peer protocol, and persistent-state molds.
::
/-  *kademlia
|%
+$  protocol-version  @tas
+$  lookup-id         @uv
+$  request-id        @uv
+$  command
  $%  [%set-seeds ships=(list @p)]
      [%find id=lookup-id target=node-id]
      [%forget id=lookup-id]
  ==
+$  peer-message
  $%  [%find-node version=protocol-version id=request-id target=node-id]
      [%nodes version=protocol-version id=request-id contacts=(list node-id)]
  ==
+$  pending-request
  $:  lookup=lookup-id
      peer=node-id
      sent=@da
      deadline=@da
  ==
+$  lookup-result
  [target=node-id contacts=(list node-id)]
+$  lookup-view
  $%  [%running state=lookup]
      [%complete result=lookup-result]
  ==
+$  summary
  $:  self=node-id
      seeds=@ud
      active=@ud
      pending=@ud
      completed=@ud
  ==
+$  state-0
  $:  %0
      routing=table
      seeds=(set node-id)
      active=(map lookup-id lookup)
      pending=(map request-id pending-request)
      completed=(map lookup-id lookup-result)
      next-request=request-id
  ==
+$  versioned-state
  $%  state-0
  ==
--
