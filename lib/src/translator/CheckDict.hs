import qualified Data.Map
import Data.List

langs = words "Bul Chi Eng Fin Fre Ger Hin Ita Spa Swe"

createAllConcretes = do
  createAbstract
  mapM_ createConcrete langs

createAbstract = do
  bnc <- readFile "bnc-to-check.txt" >>= return . words                            -- list of BNC funs
  writeFile (gfFile "todo/tmp/TopDictionary" "") $ 
    unlines $ ["abstract TopDictionary = Cat **{"] ++ 
              [unwords ("fun":f:":": snd (splitFun f) :[";"]) | f <- bnc] ++ ["}"] -- print inspectable file, to todo/tmp/

createConcrete lang = do
  bnc <- readFile "bnc-to-check.txt" >>= return . words                                -- list of BNC funs
  dict <- readFile (gfFile "Dictionary" lang) >>= return . lines                       -- current lang lexicon
  let header = getHeader dict
  let dictmap = Data.Map.fromList [(f,unwords ws) | "lin":f:"=":ws <- map words dict]  -- lin rules to a map
  let bncdict = [(f,lookupFun f dictmap) | f <- bnc]                                   -- current lang for BNC
  writeFile (gfFile "todo/tmp/TopDictionary" lang) $ 
    unlines $ toTop header ++ [unwords ("lin":f:"=":[ws]) | (f,ws) <- bncdict] ++ ["}"] -- print inspectable file, to todo/tmp/

gfFile body lang = body ++ lang ++ ".gf"

mergeDict lang = do
  old <- readFile (gfFile      "Dictionary" lang) >>= return . lines                      -- read old lexicon
  new <- readFile (gfFile "todo/TopDictionary" lang) >>= return . lines                   -- read corrected and new words
  let header = getHeader new
  let oldmap = Data.Map.fromList [(f,unwords ws) | "lin":f:"=":ws <- map words old]
  let newlist = [(f,unwords (takeWhile (/= "--") ws)) | "lin":f:"=":ws <- map words new]  -- drop comments from corrected words
  let newmap = foldr (uncurry Data.Map.insert) oldmap newlist                             -- insert corrected words
  writeFile (gfFile "tmp/Dictionary" lang) $ 
    unlines $ fromTop header ++ [unwords ("lin":f:"=":[ws]) | (f,ws) <- Data.Map.assocs newmap] ++ ["}"]  -- print revised file to tmp/

-- get the part of Dict before the first lin rule
getHeader = takeWhile ((/= "lin") . take 3)

toTop = map tt where
  tt s = case s of
    'D':'i':'c':'t':cs -> "TopDict" ++ tt cs
    c:cs               -> c : tt cs
    _ -> s

fromTop = map tt where
  tt s = case s of
    'T':'o':'p':'D':'i':'c':'t':cs -> "Dict" ++ tt cs
    c:cs               -> c : tt cs
    _ -> s

-- try to find lin rules by searching first literally, then subcategories in priority order

lookupFun f dictmap = case look f of
  Just rule -> rule
  _ -> case [r | Just r <- map look (subCats f), head (words r) `notElem` ["variants","variants{}"]] of
    rule:_ -> "variants{}; -- " ++ rule  -- cannot return it as such, as probably type incorrect
    _ -> "variants{} ; -- "
 where
  look = flip Data.Map.lookup dictmap

subCats f = case splitFun f of
  (fun,cat) -> case cat of
   "V"   -> [fun ++ c | c <- words "V2 V3 VS VQ VA VV V2S V2Q V2A V2V"]
   "V2"  -> [fun ++ c | c <- words "V3 V2S V2Q V2A V2V V VS VQ VA VV"]
   "VS"  -> [fun ++ c | c <- words "VQ V2S V2Q V2 V V2A V2V V3 VA VV"]
   "VQ"  -> [fun ++ c | c <- words "VS V2Q V2S V2 V V2A V2V V3 VA VV"]
   "VA"  -> [fun ++ c | c <- words "V V2A V2 V3 VS VQ VV V2S V2Q V2V"]
   "VV"  -> [fun ++ c | c <- words "V2V V V2 V3 VS VQ VV V2S V2Q V2V"]
   "V3"  -> [fun ++ c | c <- words "V2 V2S V2Q V2A V2V V VS VQ VA VV"]
   "V2S" -> [fun ++ c | c <- words "VS VQ V2Q V2A V2V V2 V3 VA V VV"]
   "V2Q" -> [fun ++ c | c <- words "VQ VS V2S V2A V2V V2 V3 VA V VV"]
   "V2A" -> [fun ++ c | c <- words "VA V2 V3 V VS VQ VV V2S V2Q V2V"]
   "V2V" -> [fun ++ c | c <- words "VV V2 V2 V VS VQ VV V2S V2Q V2V"]
   "Adv" -> [fun ++ c | c <- words "AdV Prep"]
   "AdV" -> [fun ++ c | c <- words "Adv Prep"]
   _ -> []

splitFun f = case span (/='_') (reverse f) of (tac,nuf) -> (reverse nuf, reverse tac)

