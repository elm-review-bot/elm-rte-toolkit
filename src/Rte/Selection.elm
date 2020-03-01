module Rte.Selection exposing (caretSelection, clearSelectionAnnotations, domToEditor, editorToDom, isCollapsed, markSelection, normalizeSelection, rangeSelection, selectionFromMarks, singleNodeRangeSelection)

import Rte.Annotation exposing (addAnnotationAtPath, clearAnnotations)
import Rte.Model exposing (Annotation, ChildNodes(..), EditorBlockNode, EditorInlineLeaf(..), ElementParameters, HtmlNode(..), Mark, NodePath, Selection, Spec, selectionAnnotation)
import Rte.Node exposing (EditorNode(..), indexedFoldl, map)
import Rte.NodePath as Path
import Set exposing (Set)


domToEditor : Spec -> EditorBlockNode -> Selection -> Maybe Selection
domToEditor =
    transformSelection Path.domToEditor


editorToDom : Spec -> EditorBlockNode -> Selection -> Maybe Selection
editorToDom =
    transformSelection Path.editorToDom


transformSelection : (Spec -> EditorBlockNode -> NodePath -> Maybe NodePath) -> Spec -> EditorBlockNode -> Selection -> Maybe Selection
transformSelection transformation spec node selection =
    case transformation spec node selection.anchorNode of
        Nothing ->
            Nothing

        Just anchorNode ->
            case transformation spec node selection.focusNode of
                Nothing ->
                    Nothing

                Just focusNode ->
                    Just <| rangeSelection anchorNode selection.anchorOffset focusNode selection.focusOffset


{-| This is a helper method for constructing a caret selection.
-}
caretSelection : NodePath -> Int -> Selection
caretSelection nodePath offset =
    singleNodeRangeSelection nodePath offset offset


{-| This is a helper method for determining if a selection is collapsed.
-}
isCollapsed : Selection -> Bool
isCollapsed selection =
    selection.anchorOffset == selection.focusOffset && selection.anchorNode == selection.focusNode


{-| This is a helper method for creating a range selection
-}
rangeSelection : NodePath -> Int -> NodePath -> Int -> Selection
rangeSelection anchorNode anchorOffset focusNode focusOffset =
    { anchorOffset = anchorOffset
    , anchorNode = anchorNode
    , focusOffset = focusOffset
    , focusNode = focusNode
    }


{-| This is a helper method for creating a selection over a single node
-}
singleNodeRangeSelection : NodePath -> Int -> Int -> Selection
singleNodeRangeSelection node anchorOffset focusOffset =
    rangeSelection node anchorOffset node focusOffset


{-| Sorts the selection's anchor to be before the focus. This method is helpful because in the selection
API, a selection's anchor node is not always before a selection's focus node, but when reasoning about editor
operations, we want the anchor to be before the focus.
-}
normalizeSelection : Selection -> Selection
normalizeSelection selection =
    case compare selection.anchorNode selection.focusNode of
        EQ ->
            { selection | anchorOffset = min selection.focusOffset selection.anchorOffset, focusOffset = max selection.focusOffset selection.anchorOffset }

        LT ->
            selection

        GT ->
            { selection | focusNode = selection.anchorNode, focusOffset = selection.anchorOffset, anchorNode = selection.focusNode, anchorOffset = selection.focusOffset }


markSelection : Selection -> EditorBlockNode -> EditorBlockNode
markSelection selection node =
    addSelectionAnnotationAtPath selection.focusNode <| addSelectionAnnotationAtPath selection.anchorNode node


addSelectionAnnotationAtPath : NodePath -> EditorBlockNode -> EditorBlockNode
addSelectionAnnotationAtPath nodePath node =
    Result.withDefault node (addAnnotationAtPath selectionAnnotation nodePath node)


clearSelectionAnnotations : EditorBlockNode -> EditorBlockNode
clearSelectionAnnotations =
    clearAnnotations selectionAnnotation


getAnnotationsFromNode : EditorNode -> Set Annotation
getAnnotationsFromNode node =
    case node of
        BlockNodeWrapper blockNode ->
            blockNode.parameters.annotations

        InlineLeafWrapper inlineLeaf ->
            case inlineLeaf of
                InlineLeaf p ->
                    p.parameters.annotations

                TextLeaf p ->
                    p.annotations


selectionFromMarks : EditorBlockNode -> Int -> Int -> Maybe Selection
selectionFromMarks node anchorOffset focusOffset =
    case findNodeRangeFromSelectionMarks node of
        Nothing ->
            Nothing

        Just ( start, end ) ->
            Just (rangeSelection start anchorOffset end focusOffset)


findNodeRangeFromSelectionMarks : EditorBlockNode -> Maybe ( NodePath, NodePath )
findNodeRangeFromSelectionMarks node =
    let
        marks =
            indexedFoldl
                (\path n agg ->
                    if Set.member selectionAnnotation <| getAnnotationsFromNode n then
                        path :: agg

                    else
                        agg
                )
                []
                (BlockNodeWrapper node)
    in
    case marks of
        [] ->
            Nothing

        [ x ] ->
            Just ( x, x )

        end :: start :: _ ->
            Just ( start, end )
