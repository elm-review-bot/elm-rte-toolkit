module Rte.Paste exposing (..)

import Array exposing (Array)
import List.Extra
import Result exposing (Result)
import Rte.Commands exposing (removeRangeSelection)
import Rte.Model exposing (ChildNodes(..), Command, Editor, EditorBlockNode, EditorFragment(..), EditorInlineLeaf(..), EditorNode(..), PasteEvent, Spec, inlineLeafArray)
import Rte.Node exposing (findTextBlockNodeAncestor, nodeAt, replaceWithFragment, splitTextLeaf)
import Rte.NodePath exposing (parent)
import Rte.Selection exposing (caretSelection, isCollapsed)
import Rte.Spec exposing (htmlToElementArray)
import Set


handlePaste : PasteEvent -> Editor msg -> Editor msg
handlePaste event editor =
    editor


pasteText : String -> Command
pasteText text editorState =
    case editorState.selection of
        Nothing ->
            Err "Nothing is selected"

        Just selection ->
            if not <| isCollapsed selection then
                removeRangeSelection editorState |> Result.andThen (pasteText text)

            else
                let
                    lines =
                        String.split "\n" text
                in
                case findTextBlockNodeAncestor selection.anchorNode editorState.root of
                    Nothing ->
                        Err "I can only paste test if there is a text block ancestor"

                    Just ( tbPath, tbNode ) ->
                        let
                            newLines =
                                List.map
                                    (\line ->
                                        { parameters = tbNode.parameters
                                        , childNodes =
                                            inlineLeafArray <|
                                                Array.fromList
                                                    [ TextLeaf
                                                        { text = line
                                                        , marks = []
                                                        , annotations = Set.empty
                                                        }
                                                    ]
                                        }
                                    )
                                    lines

                            fragment =
                                BlockNodeFragment (Array.fromList newLines)
                        in
                        pasteFragment fragment editorState


pasteHtml : Spec -> String -> Command
pasteHtml spec html editorState =
    case htmlToElementArray spec html of
        Err s ->
            Err s

        Ok fragmentArray ->
            Array.foldl
                (\fragment result ->
                    case result of
                        Err _ ->
                            result

                        Ok state ->
                            pasteFragment fragment state
                )
                (Ok editorState)
                fragmentArray


pasteFragment : EditorFragment -> Command
pasteFragment fragment editorState =
    case fragment of
        InlineLeafFragment a ->
            pasteInlineArray a editorState

        BlockNodeFragment a ->
            pasteBlockArray a editorState


pasteInlineArray : Array EditorInlineLeaf -> Command
pasteInlineArray inlineFragment editorState =
    case editorState.selection of
        Nothing ->
            Err "Nothing is selected"

        Just selection ->
            if not <| isCollapsed selection then
                removeRangeSelection editorState |> Result.andThen (pasteInlineArray inlineFragment)

            else
                case findTextBlockNodeAncestor selection.anchorNode editorState.root of
                    Nothing ->
                        Err "I can only paste an inline array into a text block node"

                    Just ( path, node ) ->
                        case node.childNodes of
                            BlockArray _ ->
                                Err "I cannot add an inline array to a block array"

                            Leaf ->
                                Err "I cannot add an inline array to a block leaf"

                            InlineLeafArray a ->
                                case List.Extra.last selection.anchorNode of
                                    Nothing ->
                                        Err "Invalid state, somehow the anchor node is the root node"

                                    Just index ->
                                        case Array.get index a.array of
                                            Nothing ->
                                                Err "Invalid anchor node path"

                                            Just inlineNode ->
                                                case inlineNode of
                                                    TextLeaf tl ->
                                                        let
                                                            ( previous, next ) =
                                                                splitTextLeaf selection.anchorOffset tl

                                                            newFragment =
                                                                Array.fromList <| TextLeaf previous :: (Array.toList inlineFragment ++ [ TextLeaf next ])

                                                            replaceResult =
                                                                replaceWithFragment selection.anchorNode (InlineLeafFragment newFragment) editorState.root

                                                            newSelection =
                                                                caretSelection (path ++ [ index + Array.length inlineFragment + 1 ]) 0
                                                        in
                                                        case replaceResult of
                                                            Err s ->
                                                                Err s

                                                            Ok newRoot ->
                                                                Ok { editorState | selection = Just newSelection, root = newRoot }

                                                    InlineLeaf _ ->
                                                        let
                                                            replaceResult =
                                                                replaceWithFragment selection.anchorNode (InlineLeafFragment inlineFragment) editorState.root

                                                            newSelection =
                                                                caretSelection (path ++ [ index + Array.length inlineFragment - 1 ]) 0
                                                        in
                                                        case replaceResult of
                                                            Err s ->
                                                                Err s

                                                            Ok newRoot ->
                                                                Ok { editorState | selection = Just newSelection, root = newRoot }


pasteBlockArray : Array EditorBlockNode -> Command
pasteBlockArray blockFragment editorState =
    -- split, add nodes, select beginning, join backwards, select end, join forward
    case editorState.selection of
        Nothing ->
            Err "Nothing is selected"

        Just selection ->
            if not <| isCollapsed selection then
                removeRangeSelection editorState |> Result.andThen (pasteBlockArray blockFragment)

            else
                let
                    parentPath =
                        parent selection.anchorNode
                in
                case nodeAt parentPath editorState.root of
                    Nothing ->
                        Err "I cannot find the parent node of the selection"

                    Just parentNode ->
                        case parentNode of
                            InlineLeafWrapper _ ->
                                Err "Invalid parent node"

                            BlockNodeWrapper bn ->
                                case bn.childNodes of
                                    Leaf ->
                                        Err "Invalid parent node, somehow the parent node was a leaf"

                                    BlockArray _ ->
                                        case replaceWithFragment selection.anchorNode (BlockNodeFragment blockFragment) editorState.root of
                                            Err s ->
                                                Err s

                                            Ok newRoot ->
                                                case List.Extra.last selection.anchorNode of
                                                    Nothing ->
                                                        Err "Invalid anchor node, somehow the parent is root"

                                                    Just index ->
                                                        let
                                                            newSelection =
                                                                caretSelection (parentPath ++ [ index + Array.length blockFragment - 1 ]) 0
                                                        in
                                                        Ok { editorState | root = newRoot, selection = Just newSelection }

                                    InlineLeafArray a ->
                                        -- split
                                        -- add nodes
                                        -- select beginning and join backwards
                                        -- select end and join forward
                                        Err "Not implemented"
