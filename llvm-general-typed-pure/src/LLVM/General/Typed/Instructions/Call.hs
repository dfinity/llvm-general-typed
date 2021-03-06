{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module LLVM.General.Typed.Instructions.Call
  ( CanCall
  , CallResult
  , call
  , tailcall
  ) where

import Data.Proxy
import GHC.Generics
import GHC.Exts (Constraint)
import qualified LLVM.General.AST as AST

import LLVM.General.Typed.BasicBlock
import LLVM.General.Typed.FreshName
import LLVM.General.Typed.Function
import LLVM.General.Typed.Instructions.Apply
import LLVM.General.Typed.Value
import LLVM.General.Typed.ValueOf

type family CanCall ty args :: Constraint
type instance CanCall ty args = (Generic args, Apply (ArgumentList ty) (Rep args), ValueOf (CallResult ty args))

type family CallResult ty args :: *
type instance CallResult ty args = ApplicationResult (ArgumentList ty) (Rep args)

call_
  :: forall args cconv ty
   . CanCall ty args
  => Bool
  -> Function cconv ty
  -> args
  -> BasicBlock (Value 'Operand (CallResult ty args))
call_ isTailCall (Function (ValueConstant f) cconv) args = do
  args' <- apply (Proxy :: Proxy (ArgumentList ty)) (from args)
  let instr = AST.Call
        { isTailCall = isTailCall
        , callingConvention = cconv
        , returnAttributes = []
        , function = Right (AST.ConstantOperand f)
        , arguments = (,[]) <$> args'
        , functionAttributes = []
        , metadata = []
        }
      ty = valueType (Proxy :: Proxy (CallResult ty args))
  ValuePure <$> nameInstruction ty instr

call
  :: forall args cconv ty
   . CanCall ty args
  => Function cconv ty
  -> args
  -> BasicBlock (Value 'Operand (CallResult ty args))
call = call_ False

tailcall
  :: forall args cconv ty
   . CanCall ty args
  => Function cconv ty
  -> args
  -> BasicBlock (Value 'Operand (CallResult ty args))
tailcall = call_ True
