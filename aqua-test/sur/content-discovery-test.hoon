::  Typed expectations checked by the discovery Aqua observer.
::
/-  *content-routing, *content-discovery, *content-discovery-agent
|%
+$  discovery-expectation
  $%  [%advertised records=@ud min-accepted=@ud]
      [%topic catalogs=@ud children=(list @tas)]
  ==
+$  discovery-observer-command
  [%expect id=operation-id value=discovery-expectation]
--
