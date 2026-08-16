::  Expectations checked inside virtual ships by the Aqua test observer.
::
/-  *kademlia, *kademlia-agent, *content-routing, *content-routing-agent
|%
+$  lookup-expectation
  [target=node-id expected=(list node-id)]
+$  operation-expectation
  $%  [%publication min-accepted=@ud]
      [%pointer publisher=node-id revision=@ud target=target]
      [%provider provider=node-id content=digest location=locator]
  ==
+$  observer-command
  $%  [%expect-lookup id=lookup-id value=lookup-expectation]
      [%expect-operation id=operation-id value=operation-expectation]
  ==
--
