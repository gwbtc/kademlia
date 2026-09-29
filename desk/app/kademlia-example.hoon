::  kademlia-example: a minimal agent wrapped with all four layers
::
::    Send commands by poking this agent with the %kademlia-command,
::    %content-routing-command, %content-discovery-command and
::    %content-store-command marks.  A
::    command that names this agent as its recipient gets its result back
::    as a poke, handled in +on-poke below.
::
/+  default-agent, dbug, verb
/+  kademlia-agent, content-routing-agent, content-discovery-agent
/+  content-store-agent
|%
+$  card  card:agent:gall
--
%+  verb  |
%-  agent:dbug
%-  agent:content-store-agent
%-  agent:content-discovery-agent
%-  agent:content-routing-agent
%-  agent:kademlia-agent
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
::
++  on-init   on-init:def
++  on-save   on-save:def
++  on-load   on-load:def
++  on-watch  on-watch:def
++  on-peek   on-peek:def
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?.  ?=  $?  %kademlia-result
              %content-routing-result
              %content-discovery-result
              %content-store-result
          ==
      mark
    (on-poke:def mark vase)
  ?>  =(our src):bowl
  %-  (slog leaf+"{<dap.bowl>}: got {<mark>}" ~)
  `this
--
