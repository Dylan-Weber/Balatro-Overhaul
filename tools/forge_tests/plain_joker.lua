return function(key, area, append)
  area = area or G.jokers
  local roll = poll_edition
  poll_edition = function() return nil end
  local ok, card = pcall(create_card, "Joker", area, nil, nil, nil, nil, key, append)
  poll_edition = roll
  if not ok then error(card, 0) end
  return card
end
