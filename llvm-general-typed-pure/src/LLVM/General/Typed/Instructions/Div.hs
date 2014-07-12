{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

module LLVM.General.Typed.Instructions.Div
  ( CanDiv
  , Div
  , LLVM.General.Typed.Instructions.Div.div
  ) where

import Data.Bits
import Data.Proxy
import GHC.Exts (Constraint)
import qualified LLVM.General.AST as AST
import qualified LLVM.General.AST.Constant as Constant

import LLVM.General.Typed.BasicBlock
import LLVM.General.Typed.FreshName
import LLVM.General.Typed.Value
import LLVM.General.Typed.ValueOf
import LLVM.General.Typed.ValueJoin
import LLVM.General.Typed.VMap

idiv
  :: forall cx cy a
   . (Bits a, ValueOf (Value (cx `Weakest` cy) a))
  => Value cx a
  -> Value cy a
  -> Value (cx `Weakest` cy) a
idiv = vmap2 f g where
  si = isSigned (undefined :: a)
  (cf, gf) = if si then (Constant.SDiv, AST.SDiv) else (Constant.UDiv, AST.UDiv)
  f = cf False
  ty = valueType (Proxy :: Proxy (Value (cx `Weakest` cy) a))
  g x y = nameInstruction ty $ gf False x y []

fdiv
  :: forall cx cy a
   . ValueOf (Value (cx `Weakest` cy) a)
  => Value cx a
  -> Value cy a
  -> Value (cx `Weakest` cy) a
fdiv = vmap2 f g where
  f = Constant.FDiv
  ty = valueType (Proxy :: Proxy (Value (cx `Weakest` cy) a))
  g x y = nameInstruction ty $ AST.FDiv AST.NoFastMathFlags x y []

class Div (classification :: Classification) where
  -- nasty :(
  type DivConstraint classification a :: Constraint
  type DivConstraint classification a = ()
  vdiv
    :: (ClassificationOf (Value (cx `Weakest` cy) a) ~ classification, DivConstraint classification a, ValueOf (Value (cx `Weakest` cy) a))
    => Value cx a
    -> Value cy a
    -> Value (cx `Weakest` cy) a

instance Div 'IntegerClass where
  type DivConstraint 'IntegerClass a = Bits a
  vdiv = idiv

instance Div ('VectorClass 'IntegerClass) where
  type DivConstraint ('VectorClass 'IntegerClass) a = Bits a
  vdiv = idiv

instance Div 'FloatingPointClass where
  vdiv = fdiv

instance Div ('VectorClass 'FloatingPointClass) where
  vdiv = fdiv

type family CanDiv (a :: *) (b :: *) :: Constraint
type instance CanDiv (Value cx a) (Value cy a) = (Div (ClassificationOf (Value (cx `Weakest` cy) a)), DivConstraint (ClassificationOf (Value (cx `Weakest` cy) a)) a, ValueOf (Value (cx `Weakest` cy) a))

div
  :: CanDiv (Value cx a) (Value cy a)
  => Value cx a
  -> Value cy a
  -> BasicBlock (Value (cx `Weakest` cy) a)
div x y = vjoin $ vdiv x y
