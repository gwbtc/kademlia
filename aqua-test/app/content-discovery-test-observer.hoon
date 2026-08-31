::  In-pier completion observer for topic-discovery Aqua tests.
::
/-  *content-routing, *content-discovery, *content-discovery-agent
/-  *content-discovery-test
/+  default-agent, dbug, verb
=/  result-matches
  |=  [expected=discovery-expectation actual=discovery-result]
  ^-  ?
  ?-  -.expected
    %advertised
      ?.  ?=(%advertised -.actual)  |
      ?&  =(records.expected (lent records.value.actual))
          %+  lien  records.value.actual
          |=  result=publication-result
          (gte (lent ~(tap in accepted.result)) min-accepted.expected)
      ==
    %topic
      ?.  ?=(%topic -.actual)  |
      =/  selected=topic-selection  selection.value.actual
      =/  children=(list @tas)
        (turn children.selected |=(child=child-selection name.child))
      ?&  =(catalogs.expected (lent catalogs.selected))
          =(children.expected children)
      ==
  ==
::
=|  expectations=(map operation-id discovery-expectation)
::
%+  verb  |
%-  agent:dbug
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init  `this
++  on-save  !>(expectations)
++  on-load
  |=  old=vase
  `this(expectations !<((map operation-id discovery-expectation) old))
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card:agent:gall _this)
  ?+  mark  (on-poke:def mark vase)
    %content-discovery-result
      =/  notice=operation-notice  !<(operation-notice vase)
      ?>  =(src.bowl our.bowl)
      ?>  ?=([%operation @ ~] reply-path.notice)
      =/  id=(unit @uv)  (slaw %uv i.t.reply-path.notice)
      ?~  id  (on-poke:def mark vase)
      =/  expected=(unit discovery-expectation)
        (~(get by expectations) u.id)
      ?~  expected  (on-poke:def mark vase)
      ?>  (result-matches u.expected result.notice)
      =.  expectations  (~(del by expectations) u.id)
      :_  this
      :_  ~
      :*  %pass  /content-discovery-test-observer  %arvo  %d
          %flog  %text
          "content-discovery-test-observer {(spud reply-path.notice)} complete"
      ==
    %noun
      ?>  =(src.bowl our.bowl)
      =/  command=discovery-observer-command
        ;;(discovery-observer-command q.vase)
      =.  expectations
        (~(put by expectations) id.command value.command)
      `this
  ==
::
++  on-peek   on-peek:def
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
