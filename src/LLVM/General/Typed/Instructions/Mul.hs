{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module LLVM.General.Typed.Instructions.Mul
  ( CanMul
  , Mul
  , mul
  ) where

import GHC.Exts (Constraint)
import qualified LLVM.General.AST as AST
import qualified LLVM.General.AST.Constant as Constant

import LLVM.General.Typed.BasicBlock
import LLVM.General.Typed.FreshName
import LLVM.General.Typed.Value
import LLVM.General.Typed.ValueOf
import LLVM.General.Typed.ValueJoin
import LLVM.General.Typed.VMap

class Mul (classification :: Classification) where
  vmul
    :: ClassificationOf (Value (cx `Weakest` cy) a) ~ classification
    => Value cx a
    -> Value cy a
    -> Value (cx `Weakest` cy) a

instance Mul 'IntegerClass where
 vmul = vmap2 f g where
   f = Constant.Mul False False
   g x y = nameInstruction $ AST.Mul False False x y []

instance Mul 'FloatingPointClass where
 vmul = vmap2 f g where
   f = Constant.FMul
   g x y = nameInstruction $ AST.FMul x y []

type family CanMul (a :: *) (b :: *) :: Constraint
type instance CanMul (Value cx a) (Value cy a) = Mul (ClassificationOf (Value (cx `Weakest` cy) a))

mul
  :: CanMul (Value cx a) (Value cy a)
  => Value cx a
  -> Value cy a
  -> BasicBlock (Value (cx `Weakest` cy) a)
mul x y = vjoin $ vmul x y