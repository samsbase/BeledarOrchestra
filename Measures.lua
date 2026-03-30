local ADDON_NAME, ns = ...

ns.MEASURES = {
    [1] = {
        [1] = "VIOLIN", [2] = "CONGRATS", [3] = "VIOLIN", [4] = "ROAR", [5] = "CONGRATS", [6] = "APPLAUD", [7] = "SING", [8] = "CHEER", [9] = "ROAR", [10] = "DANCE", 
        [11] = "SING", [12] = "CONGRATS", [13] = "ROAR", [14] = "CHEER", [15] = "SING", [16] = "PLACEHOLDER", [17] = "PLACEHOLDER", [18] = "CHEER", [19] = "APPLAUD", [20] = "SING", 
        [21] = "APPLAUD", [22] = "DANCE", [23] = "VIOLIN", [24] = "DANCE", [25] = "VIOLIN", [26] = "DANCE", [27] = "SING", [28] = "PLACEHOLDER", [29] = "DANCE", [30] = "DANCE", 
        [31] = "DANCE", [32] = "APPLAUD", [33] = "ROAR", [34] = "SING", [35] = "APPLAUD", [36] = "SING", [37] = "CHEER", [38] = "DANCE", [39] = "CHEER", [40] = "VIOLIN"
    },
    [2] = {
        [1] = "ROAR", [2] = "CONGRATS", [3] = "CHEER", [4] = "ROAR", [5] = "APPLAUD", [6] = "ROAR", [7] = "APPLAUD", [8] = "SING", [9] = "APPLAUD", [10] = "ROAR", 
        [11] = "SING", [12] = "VIOLIN", [13] = "CHEER", [14] = "SING", [15] = "ROAR", [16] = "CHEER", [17] = "APPLAUD", [18] = "DANCE", [19] = "APPLAUD", [20] = "SING", 
        [21] = "ROAR", [22] = "CHEER", [23] = "CHEER", [24] = "SING", [25] = "SING", [26] = "SING", [27] = "SING", [28] = "DANCE", [29] = "CHEER", [30] = "CHEER", 
        [31] = "ROAR", [32] = "APPLAUD", [33] = "ROAR", [34] = "APPLAUD", [35] = "APPLAUD", [36] = "APPLAUD", [37] = "ROAR", [38] = "SING", [39] = "ROAR", [40] = "SING"
    },
    [3] = {
        [1] = "APPLAUD", [2] = "SING", [3] = "APPLAUD", [4] = "ROAR", [5] = "VIOLIN", [6] = "SING", [7] = "SING", [8] = "APPLAUD", [9] = "ROAR", [10] = "APPLAUD", 
        [11] = "DANCE", [12] = "APPLAUD", [13] = "VIOLIN", [14] = "DANCE", [15] = "ROAR", [16] = "CONGRATS", [17] = "SING", [18] = "SING", [19] = "CHEER", [20] = "CONGRATS", 
        [21] = "APPLAUD", [22] = "APPLAUD", [23] = "SING", [24] = "VIOLIN", [25] = "DANCE", [26] = "SING", [27] = "SING", [28] = "ROAR", [29] = "APPLAUD", [30] = "CHEER", 
        [31] = "DANCE", [32] = "DANCE", [33] = "SING", [34] = "ROAR", [35] = "SING", [36] = "ROAR", [37] = "VIOLIN", [38] = "CHEER", [39] = "APPLAUD", [40] = "VIOLIN"
    },
    [4] = {
        [1] = "SING", [2] = "VIOLIN", [3] = "CONGRATS", [4] = "SING", [5] = "DANCE", [6] = "DANCE", [7] = "VIOLIN", [8] = "DANCE", [9] = "CONGRATS", [10] = "ROAR", 
        [11] = "SING", [12] = "CHEER", [13] = "SING", [14] = "SING", [15] = "DANCE", [16] = "SING", [17] = "SING", [18] = "CHEER", [19] = "SING", [20] = "APPLAUD", 
        [21] = "CONGRATS", [22] = "CONGRATS", [23] = "ROAR", [24] = "ROAR", [25] = "ROAR", [26] = "SING", [27] = "ROAR", [28] = "DANCE", [29] = "ROAR", [30] = "ROAR", 
        [31] = "CONGRATS", [32] = "CHEER", [33] = "PLACEHOLDER", [34] = "PLACEHOLDER", [35] = "ROAR", [36] = "DANCE", [37] = "CHEER", [38] = "PLACEHOLDER", [39] = "DANCE", [40] = "CHEER"
    },
    [5] = {
        [1] = "SING", [2] = "APPLAUD", [3] = "CONGRATS", [4] = "CHEER", [5] = "APPLAUD", [6] = "CONGRATS", [7] = "CHEER", [8] = "SING", [9] = "CONGRATS", [10] = "SING", 
        [11] = "DANCE", [12] = "CHEER", [13] = "CHEER", [14] = "DANCE", [15] = "SING", [16] = "ROAR", [17] = "DANCE", [18] = "ROAR", [19] = "SING", [20] = "CHEER", 
        [21] = "APPLAUD", [22] = "ROAR", [23] = "CONGRATS", [24] = "SING", [25] = "SING", [26] = "SING", [27] = "CHEER", [28] = "APPLAUD", [29] = "SING", [30] = "DANCE", 
        [31] = "SING", [32] = "SING", [33] = "APPLAUD", [34] = "ROAR", [35] = "SING", [36] = "VIOLIN", [37] = "ROAR", [38] = "VIOLIN", [39] = "SING", [40] = "CHEER"
    },
    [6] = {
        [1] = "VIOLIN", [2] = "DANCE", [3] = "SING", [4] = "CONGRATS", [5] = "CONGRATS", [6] = "SING", [7] = "VIOLIN", [8] = "APPLAUD", [9] = "SING", [10] = "CHEER", 
        [11] = "CHEER", [12] = "CHEER", [13] = "VIOLIN", [14] = "SING", [15] = "DANCE", [16] = "SING", [17] = "VIOLIN", [18] = "ROAR", [19] = "DANCE", [20] = "CHEER", 
        [21] = "CHEER", [22] = "VIOLIN", [23] = "SING", [24] = "CONGRATS", [25] = "SING", [26] = "SING", [27] = "APPLAUD", [28] = "SING", [29] = "SING", [30] = "ROAR", 
        [31] = "SING", [32] = "SING", [33] = "SING", [34] = "ROAR", [35] = "CHEER", [36] = "CHEER", [37] = "SING", [38] = "CHEER", [39] = "ROAR", [40] = "ROAR"
    },
    [7] = {
        [1] = "ROAR", [2] = "SING", [3] = "SING", [4] = "PLACEHOLDER", [5] = "APPLAUD", [6] = "VIOLIN", [7] = "CONGRATS", [8] = "CONGRATS", [9] = "CHEER", [10] = "VIOLIN", 
        [11] = "SING", [12] = "CHEER", [13] = "ROAR", [14] = "PLACEHOLDER", [15] = "ROAR", [16] = "PLACEHOLDER", [17] = "APPLAUD", [18] = "ROAR", [19] = "VIOLIN", [20] = "VIOLIN", 
        [21] = "CHEER", [22] = "PLACEHOLDER", [23] = "ROAR", [24] = "ROAR", [25] = "APPLAUD", [26] = "SING", [27] = "ROAR", [28] = "CHEER", [29] = "SING", [30] = "SING", 
        [31] = "APPLAUD", [32] = "SING", [33] = "DANCE", [34] = "CONGRATS", [35] = "VIOLIN", [36] = "CHEER", [37] = "ROAR", [38] = "CHEER", [39] = "ROAR", [40] = "ROAR"
    },
    [8] = {
        [1] = "CONGRATS", [2] = "SING", [3] = "PLACEHOLDER", [4] = "SING", [5] = "SING", [6] = "SING", [7] = "DANCE", [8] = "CHEER", [9] = "SING", [10] = "VIOLIN", 
        [11] = "APPLAUD", [12] = "CHEER", [13] = "CHEER", [14] = "DANCE", [15] = "SING", [16] = "CONGRATS", [17] = "ROAR", [18] = "PLACEHOLDER", [19] = "SING", [20] = "ROAR", 
        [21] = "DANCE", [22] = "ROAR", [23] = "SING", [24] = "APPLAUD", [25] = "PLACEHOLDER", [26] = "CONGRATS", [27] = "CHEER", [28] = "CHEER", [29] = "CHEER", [30] = "SING", 
        [31] = "SING", [32] = "SING", [33] = "ROAR", [34] = "SING", [35] = "CHEER", [36] = "CHEER", [37] = "SING", [38] = "SING", [39] = "CHEER", [40] = "VIOLIN"
    },
    [9] = {
        [1] = "PLACEHOLDER", [2] = "APPLAUD", [3] = "CONGRATS", [4] = "ROAR", [5] = "VIOLIN", [6] = "APPLAUD", [7] = "DANCE", [8] = "PLACEHOLDER", [9] = "ROAR", [10] = "SING", 
        [11] = "APPLAUD", [12] = "DANCE", [13] = "CONGRATS", [14] = "PLACEHOLDER", [15] = "CHEER", [16] = "PLACEHOLDER", [17] = "CHEER", [18] = "APPLAUD", [19] = "SING", [20] = "ROAR", 
        [21] = "SING", [22] = "SING", [23] = "CONGRATS", [24] = "PLACEHOLDER", [25] = "SING", [26] = "APPLAUD", [27] = "SING", [28] = "SING", [29] = "APPLAUD", [30] = "PLACEHOLDER", 
        [31] = "CONGRATS", [32] = "ROAR", [33] = "CONGRATS", [34] = "DANCE", [35] = "CONGRATS", [36] = "ROAR", [37] = "SING", [38] = "PLACEHOLDER", [39] = "CONGRATS", [40] = "APPLAUD"
    },
    [10] = {
        [1] = "SING", [2] = "DANCE", [3] = "ROAR", [4] = "VIOLIN", [5] = "DANCE", [6] = "ROAR", [7] = "CHEER", [8] = "VIOLIN", [9] = "VIOLIN", [10] = "DANCE", 
        [11] = "APPLAUD", [12] = "CHEER", [13] = "CHEER", [14] = "CHEER", [15] = "CHEER", [16] = "SING", [17] = "PLACEHOLDER", [18] = "ROAR", [19] = "CHEER", [20] = "ROAR", 
        [21] = "PLACEHOLDER", [22] = "CHEER", [23] = "CHEER", [24] = "DANCE", [25] = "CHEER", [26] = "CONGRATS", [27] = "SING", [28] = "CHEER", [29] = "SING", [30] = "VIOLIN", 
        [31] = "SING", [32] = "APPLAUD", [33] = "SING", [34] = "DANCE", [35] = "CHEER", [36] = "VIOLIN", [37] = "ROAR", [38] = "SING", [39] = "PLACEHOLDER", [40] = "APPLAUD"
    },
    [11] = {
        [1] = "ROAR", [2] = "ROAR", [3] = "VIOLIN", [4] = "CHEER", [5] = "ROAR", [6] = "PLACEHOLDER", [7] = "CONGRATS", [8] = "VIOLIN", [9] = "VIOLIN", [10] = "DANCE", 
        [11] = "CONGRATS", [12] = "APPLAUD", [13] = "DANCE", [14] = "ROAR", [15] = "APPLAUD", [16] = "SING", [17] = "PLACEHOLDER", [18] = "SING", [19] = "APPLAUD", [20] = "PLACEHOLDER", 
        [21] = "ROAR", [22] = "SING", [23] = "APPLAUD", [24] = "DANCE", [25] = "CHEER", [26] = "VIOLIN", [27] = "SING", [28] = "CHEER", [29] = "ROAR", [30] = "CHEER", 
        [31] = "PLACEHOLDER", [32] = "DANCE", [33] = "CHEER", [34] = "ROAR", [35] = "CONGRATS", [36] = "VIOLIN", [37] = "CONGRATS", [38] = "CONGRATS", [39] = "PLACEHOLDER", [40] = "CHEER"
    },
    [12] = {
        [1] = "ROAR", [2] = "SING", [3] = "VIOLIN", [4] = "DANCE", [5] = "SING", [6] = "VIOLIN", [7] = "ROAR", [8] = "PLACEHOLDER", [9] = "CONGRATS", [10] = "CHEER", 
        [11] = "PLACEHOLDER", [12] = "SING", [13] = "VIOLIN", [14] = "SING", [15] = "ROAR", [16] = "ROAR", [17] = "VIOLIN", [18] = "SING", [19] = "APPLAUD", [20] = "VIOLIN", 
        [21] = "PLACEHOLDER", [22] = "CONGRATS", [23] = "PLACEHOLDER", [24] = "APPLAUD", [25] = "APPLAUD", [26] = "PLACEHOLDER", [27] = "DANCE", [28] = "VIOLIN", [29] = "DANCE", [30] = "PLACEHOLDER", 
        [31] = "SING", [32] = "CHEER", [33] = "SING", [34] = "CONGRATS", [35] = "ROAR", [36] = "DANCE", [37] = "CHEER", [38] = "APPLAUD", [39] = "CHEER", [40] = "DANCE"
    },
    [13] = {
        [1] = "SING", [2] = "DANCE", [3] = "CHEER", [4] = "SING", [5] = "ROAR", [6] = "ROAR", [7] = "CHEER", [8] = "VIOLIN", [9] = "SING", [10] = "SING", 
        [11] = "ROAR", [12] = "SING", [13] = "SING", [14] = "CHEER", [15] = "APPLAUD", [16] = "ROAR", [17] = "CHEER", [18] = "ROAR", [19] = "DANCE", [20] = "ROAR", 
        [21] = "APPLAUD", [22] = "ROAR", [23] = "ROAR", [24] = "CHEER", [25] = "SING", [26] = "SING", [27] = "SING", [28] = "SING", [29] = "ROAR", [30] = "CHEER", 
        [31] = "ROAR", [32] = "ROAR", [33] = "SING", [34] = "DANCE", [35] = "SING", [36] = "APPLAUD", [37] = "DANCE", [38] = "ROAR", [39] = "APPLAUD", [40] = "CHEER"
    },
    [14] = {
        [1] = "APPLAUD", [2] = "SING", [3] = "ROAR", [4] = "CONGRATS", [5] = "DANCE", [6] = "CHEER", [7] = "APPLAUD", [8] = "DANCE", [9] = "APPLAUD", [10] = "DANCE", 
        [11] = "ROAR", [12] = "ROAR", [13] = "CHEER", [14] = "CHEER", [15] = "SING", [16] = "APPLAUD", [17] = "SING", [18] = "APPLAUD", [19] = "ROAR", [20] = "ROAR", 
        [21] = "SING", [22] = "CHEER", [23] = "CHEER", [24] = "DANCE", [25] = "PLACEHOLDER", [26] = "APPLAUD", [27] = "APPLAUD", [28] = "ROAR", [29] = "DANCE", [30] = "ROAR", 
        [31] = "ROAR", [32] = "SING", [33] = "ROAR", [34] = "DANCE", [35] = "DANCE", [36] = "APPLAUD", [37] = "APPLAUD", [38] = "CHEER", [39] = "ROAR", [40] = "APPLAUD"
    },
    [15] = {
        [1] = "APPLAUD", [2] = "ROAR", [3] = "VIOLIN", [4] = "CHEER", [5] = "APPLAUD", [6] = "SING", [7] = "APPLAUD", [8] = "SING", [9] = "PLACEHOLDER", [10] = "DANCE", 
        [11] = "CONGRATS", [12] = "DANCE", [13] = "SING", [14] = "VIOLIN", [15] = "SING", [16] = "CHEER", [17] = "CHEER", [18] = "DANCE", [19] = "SING", [20] = "SING", 
        [21] = "SING", [22] = "ROAR", [23] = "SING", [24] = "APPLAUD", [25] = "ROAR", [26] = "SING", [27] = "APPLAUD", [28] = "ROAR", [29] = "ROAR", [30] = "CHEER", 
        [31] = "SING", [32] = "APPLAUD", [33] = "ROAR", [34] = "APPLAUD", [35] = "ROAR", [36] = "ROAR", [37] = "APPLAUD", [38] = "DANCE", [39] = "SING", [40] = "VIOLIN"
    },
    [16] = {
        [1] = "CONGRATS", [2] = "ROAR", [3] = "ROAR", [4] = "DANCE", [5] = "VIOLIN", [6] = "CHEER", [7] = "SING", [8] = "ROAR", [9] = "SING", [10] = "DANCE", 
        [11] = "PLACEHOLDER", [12] = "APPLAUD", [13] = "CHEER", [14] = "SING", [15] = "CHEER", [16] = "CHEER", [17] = "SING", [18] = "CHEER", [19] = "APPLAUD", [20] = "VIOLIN", 
        [21] = "CHEER", [22] = "PLACEHOLDER", [23] = "APPLAUD", [24] = "DANCE", [25] = "CHEER", [26] = "ROAR", [27] = "APPLAUD", [28] = "VIOLIN", [29] = "SING", [30] = "SING", 
        [31] = "VIOLIN", [32] = "ROAR", [33] = "CONGRATS", [34] = "DANCE", [35] = "PLACEHOLDER", [36] = "CHEER", [37] = "DANCE", [38] = "APPLAUD", [39] = "CHEER", [40] = "APPLAUD"
    },
    [17] = {
        [1] = "SING", [2] = "DANCE", [3] = "CHEER", [4] = "CHEER", [5] = "CHEER", [6] = "DANCE", [7] = "VIOLIN", [8] = "ROAR", [9] = "APPLAUD", [10] = "SING", 
        [11] = "PLACEHOLDER", [12] = "CHEER", [13] = "SING", [14] = "VIOLIN", [15] = "APPLAUD", [16] = "CONGRATS", [17] = "PLACEHOLDER", [18] = "ROAR", [19] = "DANCE", [20] = "ROAR", 
        [21] = "APPLAUD", [22] = "APPLAUD", [23] = "SING", [24] = "CHEER", [25] = "CHEER", [26] = "SING", [27] = "VIOLIN", [28] = "APPLAUD", [29] = "ROAR", [30] = "ROAR", 
        [31] = "CONGRATS", [32] = "CHEER", [33] = "APPLAUD", [34] = "CHEER", [35] = "VIOLIN", [36] = "ROAR", [37] = "CHEER", [38] = "CONGRATS", [39] = "CONGRATS", [40] = "DANCE"
    },
    [18] = {
        [1] = "SING", [2] = "VIOLIN", [3] = "CHEER", [4] = "SING", [5] = "ROAR", [6] = "ROAR", [7] = "CHEER", [8] = "ROAR", [9] = "DANCE", [10] = "DANCE", 
        [11] = "PLACEHOLDER", [12] = "APPLAUD", [13] = "VIOLIN", [14] = "CONGRATS", [15] = "DANCE", [16] = "CHEER", [17] = "CHEER", [18] = "SING", [19] = "CHEER", [20] = "SING", 
        [21] = "SING", [22] = "ROAR", [23] = "CHEER", [24] = "SING", [25] = "ROAR", [26] = "CHEER", [27] = "DANCE", [28] = "DANCE", [29] = "DANCE", [30] = "ROAR", 
        [31] = "VIOLIN", [32] = "APPLAUD", [33] = "VIOLIN", [34] = "CHEER", [35] = "VIOLIN", [36] = "SING", [37] = "CHEER", [38] = "CONGRATS", [39] = "CHEER", [40] = "ROAR"
    },
    [19] = {
        [1] = "VIOLIN", [2] = "APPLAUD", [3] = "APPLAUD", [4] = "SING", [5] = "APPLAUD", [6] = "CONGRATS", [7] = "VIOLIN", [8] = "SING", [9] = "DANCE", [10] = "CHEER", 
        [11] = "SING", [12] = "APPLAUD", [13] = "SING", [14] = "SING", [15] = "VIOLIN", [16] = "DANCE", [17] = "APPLAUD", [18] = "DANCE", [19] = "APPLAUD", [20] = "ROAR", 
        [21] = "CHEER", [22] = "SING", [23] = "VIOLIN", [24] = "CHEER", [25] = "CHEER", [26] = "DANCE", [27] = "CHEER", [28] = "CHEER", [29] = "ROAR", [30] = "SING", 
        [31] = "CHEER", [32] = "CHEER", [33] = "APPLAUD", [34] = "SING", [35] = "ROAR", [36] = "ROAR", [37] = "CHEER", [38] = "ROAR", [39] = "CONGRATS", [40] = "VIOLIN"
    },
    [20] = {
        [1] = "SING", [2] = "CHEER", [3] = "DANCE", [4] = "ROAR", [5] = "SING", [6] = "APPLAUD", [7] = "SING", [8] = "APPLAUD", [9] = "CONGRATS", [10] = "APPLAUD", 
        [11] = "SING", [12] = "DANCE", [13] = "VIOLIN", [14] = "SING", [15] = "ROAR", [16] = "VIOLIN", [17] = "APPLAUD", [18] = "DANCE", [19] = "VIOLIN", [20] = "DANCE", 
        [21] = "DANCE", [22] = "SING", [23] = "SING", [24] = "DANCE", [25] = "APPLAUD", [26] = "ROAR", [27] = "CHEER", [28] = "DANCE", [29] = "CONGRATS", [30] = "APPLAUD", 
        [31] = "PLACEHOLDER", [32] = "ROAR", [33] = "APPLAUD", [34] = "SING", [35] = "ROAR", [36] = "DANCE", [37] = "CONGRATS", [38] = "ROAR", [39] = "DANCE", [40] = "APPLAUD"
    },
    [21] = {
        [1] = "APPLAUD", [2] = "CONGRATS", [3] = "CONGRATS", [4] = "DANCE", [5] = "APPLAUD", [6] = "CONGRATS", [7] = "CONGRATS", [8] = "APPLAUD", [9] = "DANCE", [10] = "ROAR", 
        [11] = "ROAR", [12] = "DANCE", [13] = "SING", [14] = "PLACEHOLDER", [15] = "ROAR", [16] = "VIOLIN", [17] = "SING", [18] = "DANCE", [19] = "PLACEHOLDER", [20] = "SING", 
        [21] = "APPLAUD", [22] = "CHEER", [23] = "CHEER", [24] = "APPLAUD", [25] = "APPLAUD", [26] = "VIOLIN", [27] = "DANCE", [28] = "APPLAUD", [29] = "ROAR", [30] = "CHEER", 
        [31] = "DANCE", [32] = "ROAR", [33] = "VIOLIN", [34] = "PLACEHOLDER", [35] = "CONGRATS", [36] = "APPLAUD", [37] = "ROAR", [38] = "VIOLIN", [39] = "SING", [40] = "CHEER"
    },
    [22] = {
        [1] = "VIOLIN", [2] = "ROAR", [3] = "ROAR", [4] = "ROAR", [5] = "SING", [6] = "CHEER", [7] = "CHEER", [8] = "CHEER", [9] = "SING", [10] = "ROAR", 
        [11] = "VIOLIN", [12] = "CHEER", [13] = "ROAR", [14] = "DANCE", [15] = "APPLAUD", [16] = "CHEER", [17] = "APPLAUD", [18] = "ROAR", [19] = "DANCE", [20] = "DANCE", 
        [21] = "CHEER", [22] = "SING", [23] = "DANCE", [24] = "APPLAUD", [25] = "CHEER", [26] = "SING", [27] = "DANCE", [28] = "CHEER", [29] = "PLACEHOLDER", [30] = "PLACEHOLDER", 
        [31] = "CHEER", [32] = "CHEER", [33] = "CHEER", [34] = "SING", [35] = "DANCE", [36] = "ROAR", [37] = "DANCE", [38] = "PLACEHOLDER", [39] = "DANCE", [40] = "CHEER"
    },
    [23] = {
        [1] = "PLACEHOLDER", [2] = "SING", [3] = "CONGRATS", [4] = "APPLAUD", [5] = "PLACEHOLDER", [6] = "ROAR", [7] = "CONGRATS", [8] = "DANCE", [9] = "PLACEHOLDER", [10] = "APPLAUD", 
        [11] = "DANCE", [12] = "SING", [13] = "SING", [14] = "APPLAUD", [15] = "SING", [16] = "CONGRATS", [17] = "CHEER", [18] = "VIOLIN", [19] = "SING", [20] = "DANCE", 
        [21] = "VIOLIN", [22] = "APPLAUD", [23] = "CHEER", [24] = "ROAR", [25] = "VIOLIN", [26] = "APPLAUD", [27] = "VIOLIN", [28] = "CONGRATS", [29] = "APPLAUD", [30] = "SING", 
        [31] = "DANCE", [32] = "CHEER", [33] = "ROAR", [34] = "VIOLIN", [35] = "APPLAUD", [36] = "ROAR", [37] = "APPLAUD", [38] = "ROAR", [39] = "DANCE", [40] = "APPLAUD"
    },
    [24] = {
        [1] = "APPLAUD", [2] = "APPLAUD", [3] = "APPLAUD", [4] = "SING", [5] = "DANCE", [6] = "APPLAUD", [7] = "ROAR", [8] = "SING", [9] = "DANCE", [10] = "PLACEHOLDER", 
        [11] = "APPLAUD", [12] = "DANCE", [13] = "ROAR", [14] = "PLACEHOLDER", [15] = "CHEER", [16] = "SING", [17] = "CHEER", [18] = "SING", [19] = "CHEER", [20] = "APPLAUD", 
        [21] = "CONGRATS", [22] = "DANCE", [23] = "SING", [24] = "SING", [25] = "PLACEHOLDER", [26] = "CHEER", [27] = "ROAR", [28] = "CONGRATS", [29] = "CHEER", [30] = "SING", 
        [31] = "CHEER", [32] = "CHEER", [33] = "SING", [34] = "DANCE", [35] = "ROAR", [36] = "CONGRATS", [37] = "APPLAUD", [38] = "APPLAUD", [39] = "ROAR", [40] = "CHEER"
    },
    [25] = {
        [1] = "DANCE", [2] = "APPLAUD", [3] = "ROAR", [4] = "VIOLIN", [5] = "APPLAUD", [6] = "SING", [7] = "SING", [8] = "CONGRATS", [9] = "CHEER", [10] = "CONGRATS", 
        [11] = "PLACEHOLDER", [12] = "CHEER", [13] = "APPLAUD", [14] = "APPLAUD", [15] = "CHEER", [16] = "ROAR", [17] = "ROAR", [18] = "SING", [19] = "ROAR", [20] = "DANCE", 
        [21] = "DANCE", [22] = "DANCE", [23] = "CHEER", [24] = "DANCE", [25] = "CONGRATS", [26] = "SING", [27] = "APPLAUD", [28] = "APPLAUD", [29] = "SING", [30] = "CHEER", 
        [31] = "SING", [32] = "DANCE", [33] = "DANCE", [34] = "APPLAUD", [35] = "CHEER", [36] = "SING", [37] = "DANCE", [38] = "CHEER", [39] = "VIOLIN", [40] = "SING"
    },
}

