import shouldShow from "./should-show.js";

export function stepsDone(stats) {
  let steps = 0;
  for (const stat_key in stats) {
    if (shouldShow(stat_key)) {
      const stat = stats[stat_key];
      if (
        (stat.max && stat.req >= stat.value) ||
        (!stat.max && stat.value >= stat.req)
      ) {
        steps++;
      }
    }
  }
  return steps;
}

export function percentageDone(stats) {
  let total = 0;

  for (const stat_key in stats) {
    if (shouldShow(stat_key)) {
      const stat = stats[stat_key];
      // Add the fraction of each requirement that is already satisfied
      if (stat.max) {
        if (stat.req >= stat.value) {
          total += 1;
        } else {
          total += stat.req / stat.value;
        }
      } else {
        if (stat.value >= stat.req) {
          total += 1;
        } else {
          total += stat.req > 0 ? stat.value / stat.req : 1;
        }
      }
    } else {
      const stat = stats[stat_key];
      if (stat["penalty_counts"]) {
        if (stat["penalty_counts"]["silenced"] === 0) {
          total += 1;
        }
        if (stat["penalty_counts"]["suspended"] === 0) {
          total += 1;
        }
      }
    }
  }

  const base = statsBaseNum(stats);
  return base > 0 ? Math.round((total / base) * 100) : 0;
}

export function statsBaseNum(stats) {
  if (!stats || Object.keys(stats).length === 0) {
    return 0;
  }
  return Math.max(
    Object.keys(stats).length - (stats.trust_level === 3 ? 9 : 3),
    0
  );
}

export function doesQualify(stats) {
  return stats.tl1_met ?? stats.tl2_met ?? stats.tl3_met ?? false;
}

export function nextStatToGet(stats) {
  let min_stat_key = null;
  let min = Infinity;

  for (const stat_key in stats) {
    if (shouldShow(stat_key)) {
      const stat = stats[stat_key];
      // Skip the flag-related stats (the user can't do anything about them)
      if (stat.max) {
        continue;
      }
      if (stat.value < stat.req) {
        const diff = stat.req - stat.value;
        if (diff < min) {
          min = diff;
          min_stat_key = stat_key;
        }
      }
    }
  }

  return {
    key: min_stat_key,
    left: min === Infinity ? 0 : min,
  };
}

// Core demotes a TL3 user when a stat drops below 90% of its requirement
// (TrustLevel3Requirements::LOW_WATER_MARK); the two all-time stats use 100%.
const LOW_WATER_MARK = 0.9;

export function demotionLine(stat_key, stat) {
  return stat_key.endsWith("_all_time") ? stat.req : stat.req * LOW_WATER_MARK;
}

// Returns the stat closest to the demotion line, if its margin is below
// `low_tl3_stats_minimum`. `left` is how much more the stat can drop before
// the user is demoted (0 if already below the line).
export function nextStatToLose(stats, site_settings) {
  let min_stat_key = null;
  let min = Infinity;

  for (const stat_key in stats) {
    if (shouldShow(stat_key)) {
      const stat = stats[stat_key];
      // Skip the flag-related stats (the user can't do anything about them)
      if (stat.max) {
        continue;
      }
      const margin = Math.floor(stat.value - demotionLine(stat_key, stat));
      if (margin < site_settings.low_tl3_stats_minimum && margin < min) {
        min = margin;
        min_stat_key = stat_key;
      }
    }
  }

  return {
    key: min_stat_key,
    left: min_stat_key ? Math.max(min, 0) : 0,
  };
}
