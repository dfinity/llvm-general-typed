{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

module LLVM.General.Typed.Value where

import Control.Monad.RWS.Lazy
import Control.Monad.State.Lazy
import Data.Typeable
import GHC.TypeLits (Nat)

import qualified LLVM.General.AST as AST
import qualified LLVM.General.AST.Constant as Constant

import LLVM.General.Typed.BasicBlock
import LLVM.General.Typed.FunctionDefinition

-- |
-- The Constness kind is used to tag values as being constants or operands
data Constness = Constant | Operand

type family Weakest (x :: Constness) (y :: Constness) :: Constness where
  Weakest 'Constant 'Constant = 'Constant
  Weakest x         y         = 'Operand

-- |
-- A Haskell representation of an LLVM type
data Value (const :: Constness) (a :: *) where
  ValueConstant :: Constant.Constant      -> Value 'Constant a -- A constant value
  ValueOperand  :: BasicBlock AST.Operand -> Value 'Operand a -- An unevaluated operand within a BasicBlock
  ValuePure     :: AST.Operand            -> Value 'Operand a -- A concrete operand
  ValueWeakened :: Value 'Constant a      -> Value 'Operand a -- A constant value in disguise

-- |
-- A struct is comprised of a type level list of field value types
data Struct (xs :: [*]) = Struct deriving Typeable

-- |
-- Arrays are of a fixed length and known type
data Array (n :: Nat) (a :: *) = Array deriving Typeable

constant :: Value 'Constant a -> Value 'Constant a
constant = id

class Weaken (const :: Constness) where
  weaken :: Value const a -> Value 'Operand a

instance Weaken 'Constant where
  weaken = ValueWeakened

instance Weaken 'Operand where
  weaken = id

class InjectConstant (const :: Constness) where
  injectConstant :: Constant.Constant -> Value const a

instance InjectConstant 'Operand where
  injectConstant = ValueWeakened . injectConstant

instance InjectConstant 'Constant where
  injectConstant = ValueConstant

evalConstantBasicBlock
  :: BasicBlock (Value 'Constant a)
  -> Value 'Constant a
evalConstantBasicBlock (BasicBlock v) =
  -- since this is only being used for Num instances we want to catch accidental
  -- evaluation of a block that contains mixed constant and operand values
  let m = evalRWST v () (BasicBlockState (error "evalConstantBasicBlock discards named instructions, is this what you want?") Nothing)
  in fst $ evalState (runFunctionDefinition m) (FunctionDefinitionState [] 0 [])

asOp
  :: Value const a
  -> BasicBlock AST.Operand
asOp (ValueConstant x) = return $ AST.ConstantOperand x
asOp (ValueWeakened x) = asOp x
asOp (ValueOperand x) = x
asOp (ValuePure x) = return x
