module Spec where
    
import Test.Hspec

main :: IO ()
main = hspec $
        describe "example" $
    it "1-1 is zero" $
    1 - 1 == 0 `shouldBe` True
