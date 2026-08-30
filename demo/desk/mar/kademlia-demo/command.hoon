::  JSON-facing command mark for the profiling application.
::
/-  *kademlia-demo
|_  command=demo-command
++  milliseconds
  |=  value=@ud
  ^-  @dr
  (div (mul ~s1 value) 1.000)
++  grow
  |%
  ++  noun  command
  --
++  grab
  |%
  ++  noun  demo-command
  ++  json
    |=  jon=^json
    ^-  demo-command
    ?>  ?=([%o *] jon)
    =/  object=(map @t ^json)  p.jon
    =/  action=@tas  (need (slaw %tas (string-field object 'action')))
    =/  run=run-id
      ?:  ?|(=(%network action) =(%reset action))  action
      (need (slaw %tas (string-field object 'run')))
    ?+  action  !!
      %reset
        [%reset ~]
      %create
        :*  %create
            run
            (atom-field object 'seed' %ud)
            (atom-field object 'size' %ud)
            (string-field object 'mime')
        ==
      %publish
        =/  transport=transport
          =/  value=@tas
            (need (slaw %tas (string-field object 'transport')))
          ?+  value  !!
            %custom  %custom
            %scry    %scry
          ==
        =/  named=(unit [namespace=@tas name=@t revision=@ud])
          =/  raw=(unit ^json)  (~(get by object) 'name')
          ?~  raw  ~
          ?@  u.raw  ~
          ?.  ?=([%o *] u.raw)  ~
          =/  value=(map @t ^json)  p.u.raw
          `[ `@tas`(atom-field value 'namespace' %tas)
             (string-field value 'name')
             (atom-field value 'revision' %ud)
           ]
        [%publish run (atom-field object 'content' %uv) transport named]
      %lookup
        [%lookup run `@p`(atom-field object 'target' %p)]
      %fetch-content
        [%fetch run [%content (atom-field object 'content' %uv)]]
      %fetch-name
        :*  %fetch  run
            :*  %name
                `@p`(atom-field object 'publisher' %p)
                `@tas`(atom-field object 'namespace' %tas)
                (string-field object 'name')
            ==
        ==
      %cancel
        [%cancel run]
      %network
        =/  raw-seeds=^json  (json-field object 'seeds')
        ?>  ?=([%a *] raw-seeds)
        =/  seeds=(list @p)
          %+  turn  p.raw-seeds
          |=  item=^json
          ?>  ?=([%s *] item)
          `@p`(need (slaw %p p.item))
        =/  level=@tas
          (need (slaw %tas (string-field object 'verbosity')))
        =/  verbosity=verbosity
          ?+  level  !!
            %off    %off
            %info   %info
            %debug  %debug
          ==
        :*  %network
            seeds
            (milliseconds (atom-field object 'requestTimeoutMs' %ud))
            (milliseconds (atom-field object 'refreshIntervalMs' %ud))
            verbosity
        ==
    ==
  --
++  grad  %noun
::
++  json-field
  |=  [object=(map @t ^json) key=@t]
  ^-  ^json
  (need (~(get by object) key))
::
++  string-field
  |=  [object=(map @t ^json) key=@t]
  ^-  @t
  =/  value=json  (json-field object key)
  ?>  ?=([%s *] value)
  p.value
::
++  atom-field
  |=  [object=(map @t ^json) key=@t aura=@ta]
  ^-  @
  =/  value=^json  (json-field object key)
  ?@  value  !!
  ?-  -.value
    %n  (ni:dejs:format value)
    %s  (need (slaw aura p.value))
    %a  !!
    %b  !!
    %o  !!
  ==
--
