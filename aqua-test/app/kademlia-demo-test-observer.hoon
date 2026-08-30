::  Aqua-only observer for terminal Kademlia Lab phase facts.
::
/+  default-agent, dbug, verb
=/  string-value
  |=  [object=(map @t json) key=@t]
  ^-  (unit @t)
  =/  value=(unit json)  (~(get by object) key)
  ?~  value  ~
  ?.  ?=([%s *] u.value)  ~
  `p.u.value
=|  expected=(set @tas)
%+  verb  |
%-  agent:dbug
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init  `this
++  on-save  !>(expected)
++  on-load
  |=  old=vase
  `this(expected !<((set @tas) old))
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card:agent:gall _this)
  ?.  =(%noun mark)  (on-poke:def mark vase)
  ?>  =(src.bowl our.bowl)
  =/  run=@tas  ;;(@tas q.vase)
  =.  expected  (~(put in expected) run)
  :_  this
  :_  ~
  :*  %pass  /demo/[run]  %agent  [our.bowl %kademlia-demo]
      %watch  /events
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card:agent:gall _this)
  ?.  ?=([%demo @ ~] wire)  (on-agent:def wire sign)
  ?+  -.sign  `this
    %watch-ack
      ?>  ?~(p.sign & |)
      `this
    %kick  `this
    %fact
      ?.  =(%json p.cage.sign)  `this
      =/  event=json  !<(json q.cage.sign)
      ?.  ?=([%o *] event)  `this
      =/  object=(map @t json)  p.event
      =/  type=(unit @t)  (string-value object 'type')
      =/  run=(unit @t)  (string-value object 'run')
      =/  phase=(unit @t)  (string-value object 'phase')
      ?~  type  `this
      ?~  run  `this
      ?~  phase  `this
      ?.  =('phase' u.type)  `this
      =/  parsed=(unit @tas)  (slaw %tas u.run)
      ?~  parsed  `this
      ?.  (~(has in expected) u.parsed)  `this
      ?.  ?|  =('complete' u.phase)
              =('failed' u.phase)
              =('cancelled' u.phase)
          ==
        `this
      ?.  =('complete' u.phase)
        ~|  [%demo-operation-failed event]
        !!
      =.  expected  (~(del in expected) u.parsed)
      :_  this
      :_  ~
      :*  %pass  /kademlia-demo-test-observer  %arvo  %d
          %flog  %text
          "kademlia-demo-test-observer {<u.parsed>} complete"
      ==
  ==
::
++  on-peek   on-peek:def
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
