::  In-pier completion observer for content-store Aqua tests.
::
/-  *content-routing, cra=content-routing-agent
/-  cd=content-discovery, cda=content-discovery-agent
/-  *content-store, *content-store-test
/+  client=content-store-client, default-agent, dbug, verb
|%
++  publication-accepted
  |=  [result=publication-result:cra minimum=@ud]
  ^-  ?
  (gte (lent ~(tap in accepted.result)) minimum)
::
++  advertisement-accepted
  |=  [result=advertisement-result:cda minimum=@ud]
  ^-  ?
  %+  lien  records.result
  |=  publication=publication-result:cda
  (gte (lent ~(tap in accepted.publication)) minimum)
::
++  result-matches
  |=  [expected=content-store-expectation actual=content-store-result]
  ^-  ?
  ?-  -.expected
    %put
      ?.  ?=(%put -.actual)  |
      =/  result=put-result  value.actual
      ?.  =(content.expected content.result)  |
      ?.  (publication-accepted provider.result min-accepted.expected)  |
      ?.  =(pointer.expected ?=(^ pointer.result))  |
      ?.  =(pointer-revision.expected pointer-revision.result)  |
      ?.  =(topic.expected ?=(^ topic.result))  |
      ?.  ?~(pointer.result & (publication-accepted u.pointer.result min-accepted.expected))
        |
      ?~  topic.result  &
      (advertisement-accepted u.topic.result min-accepted.expected)
    %pin
      ?.  ?=(%pin -.actual)  |
      =/  result=pin-result  value.actual
      ?&  =(content.expected content.result)
          =(fetched.expected fetched.result)
          (gth expires.result 0)
          (publication-accepted publication.result min-accepted.expected)
      ==
    %unpin
      ?.  ?=(%unpin -.actual)  |
      =(content.expected content.actual)
    %get
      ?.  ?=(%get -.actual)  |
      =/  result=get-result  value.actual
      ?&  =(content.expected content.result)
          =(value.expected value.result)
      ==
    %search
      ?.  ?=(%search -.actual)  |
      =/  result=browse-result:cda  value.value.actual
      =/  selected=topic-selection:cd  selection.result
      =/  children=(list @tas)
        (turn children.selected |=(child=child-selection:cd name.child))
      ?&  =(topic.expected topic.result)
          =(catalogs.expected (lent catalogs.selected))
          =(children.expected children)
      ==
  ==
--
::
=|  expectations=(map content-store-id content-store-expectation)
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
  `this(expectations !<((map content-store-id content-store-expectation) old))
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card:agent:gall _this)
  ?+  mark  (on-poke:def mark vase)
    %content-store-result
      =/  notice=content-store-notice  !<(content-store-notice vase)
      ?>  =(src.bowl our.bowl)
      ?>  ?=([%operation @ ~] reply-path.notice)
      =/  id=(unit @uv)  (slaw %uv i.t.reply-path.notice)
      ?~  id  (on-poke:def mark vase)
      =/  expected=(unit content-store-expectation)
        (~(get by expectations) u.id)
      ?~  expected  (on-poke:def mark vase)
      ?>  (result-matches u.expected result.notice)
      =.  expectations  (~(del by expectations) u.id)
      :_  this
      :_  ~
      :*  %pass  /content-store-test-observer  %arvo  %d
          %flog  %text
          "content-store-test-observer {(spud reply-path.notice)} complete"
      ==
    %noun
      ?>  =(src.bowl our.bowl)
      =/  command=content-store-observer-command
        ;;(content-store-observer-command q.vase)
      =.  expectations
        (~(put by expectations) id.command expected.command)
      =/  reply-path=path  /operation/(scot %uv id.command)
      =/  cards=(list card:agent:gall)
        %-  start:client
        [our.bowl id.command %content-store-test-observer reply-path command.command]
      [cards this]
  ==
::
++  on-peek   on-peek:def
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
