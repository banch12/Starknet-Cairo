%builtins output range_check

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.serialize import serialize_word
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.squash_dict import squash_dict
from starkware.cairo.common.alloc import alloc

# Build a DictAccess list for the computation of the cumulative
# sum for each key

# Sept 6, 2022
# fixes done
# build_dict: fixed prev_value and new_value logic. 
## for duplicate key, prev_value and new_value should follow following
## new_value = new_value from last same key value + current value
## prev_value = new_value from last same key value
## for single occurence key
## new_value = current value
## prev_value = 0

struct KeyValue:
    member key : felt
    member value : felt
end

func build_dict(list : KeyValue*, size, dict : DictAccess*) -> (dict:DictAccess*):

   alloc_locals

   if size == 0:
      return (dict=dict)
   end

   %{
      key = ids.list.key
      prev_value = ids.list.value
      # populate 
      # ids.dict.prev_value <-- cumulative_sums old value
      # ids.dict.new_value <-- cumulative_sums new value
      ids.dict.key = ids.list.key

      # populate cumulative_sums
      if len(cumulative_sums) == 0:
          cumulative_sums.update({key:ids.list.value})
          ids.dict.prev_value = 0
          ids.dict.new_value = ids.list.value
          #print("first entry in cumulative_sums")
      elif ids.list.key in cumulative_sums.keys():
          x = cumulative_sums.get(key)
          ids.dict.prev_value = x
          new_value = x + ids.list.value
          cumulative_sums.update({key:new_value})
          ids.dict.new_value = cumulative_sums.get(key)
          #print("++++++++++++++++++++++++++++++++++++++++")
          #print(f"from build_dict: dict.key:{ids.dict.key}")
          #print(f"from build_dict: dict.new_value:{ids.dict.new_value}")
          #print("++++++++++++++++++++++++++++++++++++++++")
          #print("in dupliicate key section")
      else:
          cumulative_sums.update({key:ids.list.value})
          ids.dict.prev_value = 0
          ids.dict.new_value = ids.list.value

      # prints for debug
      #print(f"from build_dict: cumulative_sums:{cumulative_sums}")
      #print(f"from build_dict: size = {ids.size}")
      #print(f"from build_dict: prev_value:{prev_value}")
      #print("============================================")
      #print(f"from build_dict: dict.key = {ids.dict.key}")
      #print(f"from build_dict: list.value:{ids.list.value}")
      #print(f"from build_dict: dict.prev_value:{ids.dict.prev_value}")
      #print(f"from build_dict: dict.new_value:{ids.dict.new_value}")
      #print("============================================")
   %}

    assert dict.new_value = dict.prev_value + list.value

    # call buld_dict recursively
    return build_dict(
       list=list + KeyValue.SIZE,
       size=size-1,
       dict=dict + DictAccess.SIZE
    )
end

# Verifies that the initial values were 0, and writes the final
# values to result.
func verify_and_output_squashed_dict(
    squashed_dict : DictAccess*,
    squashed_dict_end : DictAccess*,
    result : KeyValue*,
) -> (result:KeyValue*):

   tempvar diff = squashed_dict_end - squashed_dict
   if diff == 0:
      return(result=result)
   end

   assert squashed_dict.prev_value = 0

   assert result.key = squashed_dict.key
   assert result.value = squashed_dict.new_value
   
   return verify_and_output_squashed_dict(
      squashed_dict=squashed_dict + DictAccess.SIZE,
      squashed_dict_end=squashed_dict_end,
      result=result + KeyValue.SIZE
   )
end

# Given a list of KeyValue, sums the values, grouped by key,
# and returns a list of pairs (key, sum_of_values).
func sum_by_key{range_check_ptr}(list : KeyValue*, size) -> (result:KeyValue*, result_size):

   alloc_locals


   %{
       cumulative_sums = {}
   %}

   let (local dict_start : DictAccess*) = alloc()
   let (local squashed_dict : DictAccess*) = alloc()
   let (local result : KeyValue*) = alloc()
   local result_size

   let (local dict_end : DictAccess*) = build_dict(
                        list=list, # list is input to this func
                        size=size, # size is input to this func
                        dict=dict_start
                    )

   
   let (squashed_dict_end : DictAccess*) = squash_dict(
       dict_accesses=dict_start,
       dict_accesses_end=dict_end,
       squashed_dict=squashed_dict,
   )

   let(result) = verify_and_output_squashed_dict(
      squashed_dict=squashed_dict,
      squashed_dict_end=squashed_dict_end,
      result=result
   )

   assert result_size = (squashed_dict_end - squashed_dict)/DictAccess.SIZE

   %{
        print(f"result_size= {ids.result_size}")
   %}

   return (result=result, result_size=result_size)


end

# main
func main{output_ptr : felt*, range_check_ptr}():
   alloc_locals

   # define input list and size

   local list : KeyValue*
   local size : felt

   local KeyValue_tuple : (
      KeyValue, KeyValue, KeyValue, KeyValue, KeyValue
   ) = (
        KeyValue(key=3, value=5),
        KeyValue(key=1, value=10),
        KeyValue(key=3, value=1),
        KeyValue(key=3, value=8),
        KeyValue(key=1, value=20),
       )
   # get value of the frame pointer register (fp) so that we can use addr of loc_tuple Loc0
   let (__fp__, _) = get_fp_and_pc()

   let (result, result_size) = sum_by_key(list=cast(&KeyValue_tuple, KeyValue*), size=5) 

   return ()
end
