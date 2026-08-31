::  Hierarchical topic-discovery records layered above Kademlia.
::
/-  *kademlia, *content-routing
|%
+$  topic-path  (list @tas)
+$  catalog-reference
  $:  format=@tas
      digest=digest
      entries=@ud
  ==
+$  catalog-body
  $:  topic=topic-path
      key=key
      publisher=node-id
      revision=@ud
      expires=@da
      catalog=catalog-reference
  ==
+$  catalog-record
  [body=catalog-body signature=record-signature]
+$  edge-body
  $:  parent=topic-path
      key=key
      child=@tas
      source=topic-path
      publisher=node-id
      revision=@ud
      expires=@da
      catalog=catalog-reference
  ==
+$  edge-record
  [body=edge-body signature=record-signature]
+$  discovery-record
  $%  [%catalog value=catalog-record]
      [%edge value=edge-record]
  ==
+$  discovery-records  (list discovery-record)
+$  record-identity
  $%  [%catalog publisher=node-id]
      [%edge publisher=node-id source=topic-path]
  ==
+$  child-selection
  [name=@tas supporters=(set node-id)]
+$  topic-selection
  $:  catalogs=(list catalog-record)
      children=(list child-selection)
      conflicts=(set record-identity)
  ==
--
