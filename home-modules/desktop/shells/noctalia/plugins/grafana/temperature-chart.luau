local tile = require("./lib/chart.luau")("temperature")

function update() tile.update() end
function cyclePeriod() tile.cyclePeriod() end
