Require Import Verdi.Verdi.
Require Import Verdi.NameOverlay.

Require Import TreeAux.
Require Import TreeDynamic.

Require Import StructTact.Fin.

Require Import ExtrOcamlBasic.
Require Import ExtrOcamlNatInt.

Require Import ExtrOcamlBasicExt.
Require Import ExtrOcamlNatIntExt.

Require Import ExtrOcamlBool.
Require Import ExtrOcamlList.
Require Import ExtrOcamlFin.

Module NumNames : NatValue. Definition n := 5. End NumNames.
Module Names := FinName NumNames.
Module NamesOT := FinNameOrderedType NumNames Names.
Module NamesOTCompat := FinNameOrderedTypeCompat NumNames Names.
Module RootNames := FinRootNameType NumNames Names.
Module AdjacentNames := FinCompleteAdjacentNameType NumNames Names.

Require Import MSetList.
Module NamesSet <: MSetInterface.S := MSetList.Make NamesOT.

Require Import FMapList.
Module NamesMap <: FMapInterface.S := FMapList.Make NamesOTCompat.

Module TAuxNames := FinTAux NumNames Names NamesOT NamesSet NamesOTCompat NamesMap.

Module TreeNames := Tree Names NamesOT NamesSet NamesOTCompat NamesMap RootNames AdjacentNames TAuxNames.
Import TreeNames.

Extraction "extraction/tree-dynamic/ocaml/Tree.ml" seq Tree_BaseParams Tree_MultiParams.