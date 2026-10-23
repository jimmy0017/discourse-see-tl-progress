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
      if (stat.max) {
        if (stat.req >= stat.value) {
          total += 1;
        } else {
          total += (stat.value - stat.req) / stat.value;
        }
      } else {
        if (stat.value >= stat.req) {
          total += 1;
        } else {
          total += (stat.req - stat.value) / stat.req;
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

  return Math.round((total / statsBaseNum(stats)) * 100);
}

export function statsBaseNum(stats) {
  return Object.keys(stats).length - (stats.trust_level === 3 ? 9 : 3);
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

export function nextStatToLose(stats, site_settings) {
  let max_stat_key = null;
  let max = 0;

  for (const stat_key in stats) {
    if (shouldShow(stat_key)) {
      const stat = stats[stat_key];
      // Skip the flag-related stats (the user can't do anything about them)
      if (stat.max) {
        continue;
      }
      if (stat.value > stat.req) {
        const diff = stat.value - stat.req;
        if (diff >= site_settings.low_tl3_stats_minimum && diff > max) {
          max = diff;
          max_stat_key = stat_key;
        }
      }
    }
  }

  return {
    key: max_stat_key,
    left: max,
  };
}
