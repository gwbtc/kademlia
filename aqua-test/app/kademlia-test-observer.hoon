::  In-pier completion observer for the Aqua integration test.
::
::  Completion callbacks stay inside the virtual ship, avoiding `%unto` across
::  Aqua's version-sensitive Unix-effect ABI.  The observer validates each
::  result against a registered expectation and announces a small Dill marker.
::
/-  *kademlia-agent, *content-routing-agent, *kademlia-test
/+  default-agent, dbug, verb
=/  operation-matches
  |=  [expected=operation-expectation actual=operation-result]
  ^-  ?
  ?-  -.expected
    %publication
      ?.  ?=(%published -.actual)  |
      (gte (lent ~(tap in accepted.value.actual)) min-accepted.expected)
    %pointer
      ?.  ?=(%pointer -.actual)  |
      =/  selected=pointer-selection  selection.value.actual
      ?.  ?=(%found -.selected)  |
      ?&  =(publisher.expected publisher.body.record.selected)
          =(revision.expected revision.body.record.selected)
          =(target.expected target.body.record.selected)
      ==
    %provider
      ?.  ?=(%providers -.actual)  |
      %+  lien  records.selection.value.actual
      |=  record=provider
      ?&  =(content.expected content.body.record)
          =(provider.expected provider.body.record)
          %+  lien  locations.body.record
          |=  location=locator
          =(location.expected location)
      ==
  ==
::
=|  lookup-expectations=(map lookup-id lookup-expectation)
=|  operation-expectations=(map operation-id operation-expectation)
::
%+  verb  |
%-  agent:dbug
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init  `this
++  on-save  !>([lookup-expectations operation-expectations])
++  on-load
  |=  old=vase
  =/  saved
    !<  $:  (map lookup-id lookup-expectation)
            (map operation-id operation-expectation)
        ==
      old
  `this(lookup-expectations -.saved, operation-expectations +.saved)
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card:agent:gall _this)
  ?+  mark  (on-poke:def mark vase)
    %kademlia-result
      =/  notice=lookup-notice  !<(lookup-notice vase)
      ?>  =(src.bowl our.bowl)
      ?>  ?=([%lookup @ ~] reply-path.notice)
      =/  id=(unit @uv)  (slaw %uv i.t.reply-path.notice)
      ?~  id  (on-poke:def mark vase)
      =/  expected=(unit lookup-expectation)
        (~(get by lookup-expectations) u.id)
      ?~  expected  (on-poke:def mark vase)
      ?>  =(target.u.expected target.result.notice)
      ?>  %+  levy  expected.u.expected
          |=  id=node-id
          (lien contacts.result.notice |=(candidate=node-id =(id candidate)))
      =.  lookup-expectations  (~(del by lookup-expectations) u.id)
      :_  this
      :_  ~
      :*  %pass  /kademlia-test-observer  %arvo  %d
          %flog  %text
          "kademlia-test-observer {(spud reply-path.notice)} complete"
      ==
    %content-routing-result
      =/  notice=operation-notice  !<(operation-notice vase)
      ?>  =(src.bowl our.bowl)
      ?>  ?=([%operation @ ~] reply-path.notice)
      =/  id=(unit @uv)  (slaw %uv i.t.reply-path.notice)
      ?~  id  (on-poke:def mark vase)
      =/  expected=(unit operation-expectation)
        (~(get by operation-expectations) u.id)
      ?~  expected  (on-poke:def mark vase)
      ?>  (operation-matches u.expected result.notice)
      =.  operation-expectations  (~(del by operation-expectations) u.id)
      :_  this
      :_  ~
      :*  %pass  /kademlia-test-observer  %arvo  %d
          %flog  %text
          "kademlia-test-observer {(spud reply-path.notice)} complete"
      ==
    %noun
      ?>  =(src.bowl our.bowl)
      =/  command=observer-command  ;;(observer-command q.vase)
      ?-  -.command
        %expect-lookup
          =.  lookup-expectations
            (~(put by lookup-expectations) id.command value.command)
          `this
        %expect-operation
          =.  operation-expectations
            (~(put by operation-expectations) id.command value.command)
          `this
      ==
  ==
::
++  on-peek   on-peek:def
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
