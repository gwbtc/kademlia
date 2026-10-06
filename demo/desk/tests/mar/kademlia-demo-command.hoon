/-  *kademlia-demo
/+  *test
/=  command-mark  /mar/kademlia-demo/command
|%
++  test-hierarchical-name-json
  =/  jon=json
    :-  %o
    %-  malt
    :~  ['action' `^json`[%s 'fetch-name']]
        ['run' `^json`[%s 'json-test']]
        ['publisher' `^json`[%s '~zod']]
        ['namespace' `^json`[%s 'releases']]
        :-  'name'
        `^json`[%a ~[[%s 'packages'] [%s 'kademlia'] [%s 'latest']]]
    ==
  =/  command=demo-command  (json:grab:command-mark jon)
  =/  expected=demo-command
    [%fetch %json-test [%name ~zod %releases ~[%packages %kademlia %latest]]]
  (expect-eq !>(expected) !>(command))
--
