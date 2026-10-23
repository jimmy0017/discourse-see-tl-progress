import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { and, eq, gte, lt, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import Tl3ProgressModal from "../../components/tl-progress-modal.gjs";
import {
  doesQualify,
  nextStatToGet,
  nextStatToLose,
  percentageDone,
  statsBaseNum,
  stepsDone,
} from "../../lib/calculate-stats.js";

export default class Tl3ProgressButton extends Component {
  static shouldRender(args, helper) {
    const user = args.user;
    const settings = helper.siteSettings;

    if (!helper.currentUser || user.staff) {
      return false;
    }

    // Staff and user can always see it
    const canView =
      helper.currentUser.staff || user.id === helper.currentUser.id;

    const inSettings = settings.enable_for_trust_level_promotions
      .split("|")
      .includes((user.trust_level + 1).toString());

    if (user.trust_level === 3) {
      if (settings.show_warning_when_tl_requirements_low) {
        return true;
      } else {
        return false;
      }
    }
    return canView && inSettings;
  }

  @service siteSettings;
  @service session;

  @tracked modalShowing = false;
  @tracked stats;
  @tracked lockedStatus;
  @tracked stats_loading = true;
  @tracked is_locked_loading = true;

  constructor() {
    super(...arguments);
    this.getUserStats();
    this.getIsLocked();
  }

  get percentageDone() {
    return percentageDone(this.stats);
  }

  get doesQualify() {
    return doesQualify(this.stats);
  }

  get stepsDone() {
    return stepsDone(this.stats);
  }

  get progressDoneText() {
    return i18n("see_tl_progress.progress_done", {
      steps_completed: this.stepsDone,
      total_steps: statsBaseNum(this.stats),
      percentage_done: this.percentageDone,
    });
  }

  get showClosestStat() {
    return (
      this.siteSettings.show_verbose_tl_progress &&
      this.siteSettings.show_next_closest_stat &&
      this.stepsDone < 14 &&
      Boolean(nextStatToGet(this.stats))
    );
  }

  get closestStatText() {
    const closestStatObj = nextStatToGet(this.stats);
    return i18n("see_tl_progress.closest_stat", {
      stat_name: i18n(`see_tl_progress.${closestStatObj.key}`),
      stat_left_to_next: closestStatObj.left,
    });
  }

  get barsFilledOrEmpty() {
    let state = [];
    for (let i = 0; i < statsBaseNum(this.stats); i++) {
      if (i < this.stepsDone) {
        state.push(
          `background-color: ${this.session.defaultColorSchemeIsDark || this.session.darkModeAvailable ? this.siteSettings.progress_bar_color_dark : this.siteSettings.progress_bar_color_light}; width: 100%;`
        );
      } else {
        state.push(false);
      }
    }

    return state;
  }

  get barBg() {
    return `background-color: ${this.session.defaultColorSchemeIsDark || this.session.darkModeAvailable ? this.siteSettings.progress_bar_background_color_dark : this.siteSettings.progress_bar_background_color_light}`;
  }

  get showAboutToLoseTl3() {
    return (
      !this.stats.on_grace_period &&
      this.siteSettings.show_warning_when_tl_requirements_low &&
      this.args.user.trust_level === 3 &&
      Boolean(nextStatToLose(this.stats, this.siteSettings))
    );
  }

  get closestStatToLoseText() {
    const closestStatObj = nextStatToLose(this.stats, this.siteSettings);
    if (!closestStatObj) {
      return "";
    }
    return i18n("see_tl_progress.closest_stat_to_lose", {
      stat_name: i18n(
        closestStatObj.key === "days_visited" // days_visited uses its own plugin-defined locale
          ? "see_tl_progress.days_visited"
          : `see_tl_progress.${closestStatObj.key}`
      ),
      stat_left: closestStatObj.left,
    });
  }

  get showMutedTopicsAndPosts() {
    if (this.stats.trust_level === 3) {
      return !(
        this.stats.topics_viewed?.value >= this.stats.topics_viewed?.req &&
        this.stats.posts_read?.value >= this.stats.posts_read?.req &&
        this.stats.topics_viewed_all_time?.value >=
          this.stats.topics_viewed_all_time?.req &&
        this.stats.posts_read_all_time?.value >=
          this.stats.posts_read_all_time?.req
      );
    } else {
      return !(
        this.stats.topics_entered?.value >= this.stats.topics_entered?.req &&
        this.stats.posts_read?.value >= this.stats.posts_read?.req
      );
    }
  }

  get mutedTopicsAndPostsText() {
    const num_topics = this.stats.num_topics_in_muted_categories;
    const num_posts = this.stats.num_posts_in_muted_categories;

    const topics_text = i18n(
      `see_tl_progress.muted_topics_count.${num_topics === 1 ? "one" : "other"}`,
      {
        num_topics: this.stats.num_topics_in_muted_categories,
      }
    );

    const posts_text = i18n(
      `see_tl_progress.muted_posts_count.${num_posts === 1 ? "one" : "other"}`,
      {
        num_posts: this.stats.num_posts_in_muted_categories,
      }
    );

    return i18n("see_tl_progress.has_muted_topics_posts_warning", {
      muted_topics_count: topics_text,
      muted_posts_count: posts_text,
    });
  }

  get overviewHeading() {
    const tl = this.args.user.trust_level;
    if (tl === 0) {
      return i18n("see_tl_progress.modal_title_tl_1");
    } else if (tl === 1) {
      return i18n("see_tl_progress.modal_title_tl_2");
    } else {
      return i18n(
        `see_tl_progress.modal_title_tl_3.${this.stats.time_period === 1 ? "one" : "other"}`,
        {
          num_days: this.stats.time_period,
        }
      );
    }
  }

  async getUserStats() {
    try {
      const data = await ajax(`/u/${this.args.user.username}/tl-progress.json`);
      this.stats = data.stats_progress;
      this.stats_loading = false;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  async getIsLocked() {
    if (!this.siteSettings.show_locked_at_trust_level) {
      this.lockedStatus = {
        is_locked: false,
        locked_at_trust_level: null,
      };
      this.is_locked_loading = false;
      return;
    }
    try {
      const data = await ajax(`/u/${this.args.user.username}/is-locked.json`);
      this.lockedStatus = data;
      this.is_locked_loading = false;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  toggleModalState() {
    this.modalShowing = !this.modalShowing;
  }

  <template>
    {{#if (or this.stats_loading this.is_locked_loading)}}
      <DConditionalLoadingSpinner
        @condition={{or this.stats_loading this.is_locked_loading}}
      />
    {{else}}
      <h3>{{this.overviewHeading}}</h3>
      {{#if (lt @user.trust_level 3)}}
        <div class="segmented-bars">
          {{#each this.barsFilledOrEmpty as |state|}}
            <div class="segmented-bar" style={{trustHTML this.barBg}}>
              {{#if state}}
                <div class="segmented-bar-fill" style={{trustHTML state}}></div>
              {{else}}
                <div class="segmented-bar-fill"></div>
              {{/if}}
            </div>
          {{/each}}
        </div>
        <p>
          {{this.progressDoneText}}
        </p>
      {{/if}}

      {{#if this.showClosestStat}}
        <div class="inline-wrapper" id="closest-stat-text">{{dIcon "forward"}}
          {{this.closestStatText}}
        </div>
      {{/if}}
      {{#if
        (and
          this.siteSettings.show_warning_when_user_has_muted_topics_and_posts
          (or
            (gte this.stats.num_topics_in_muted_categories 1)
            (gte this.stats.num_posts_in_muted_categories 1)
          )
          (lt @user.trust_level 3)
          (lt this.stepsDone (statsBaseNum this.stats))
          this.showMutedTopicsAndPosts
        )
      }}
        <div>
          {{dIcon "triangle-exclamation"}}
          {{this.mutedTopicsAndPostsText}}
          <a href={{concat "/u/" @user.username "/preferences/tracking"}}>
            {{i18n "see_tl_progress.muted_categories_link_text"}}
          </a>
        </div>
      {{/if}}
      {{#if this.showAboutToLoseTl3}}
        <div class="inline-wrapper" id="closest-stat-to-lose-text">{{dIcon
            "triangle-exclamation"
          }}
          {{this.closestStatToLoseText}}
        </div>
      {{/if}}

      {{#if
        (and
          this.siteSettings.show_verbose_tl_progress
          (or (lt @user.trust_level 3) (eq @user.trust_level 3))
        )
      }}
        <DButton
          class="btn-primary"
          style="margin-bottom: 1em;"
          @action={{this.toggleModalState}}
          @icon={{this.siteSettings.modal_button_icon}}
          @translatedLabel={{i18n
            "see_tl_progress.modal_button_text"
            trust_level=this.stats.trust_level
          }}
        />
        {{#if this.modalShowing}}
          <DModal
            @closeModal={{this.toggleModalState}}
            @title={{this.overviewHeading}}
          >
            <Tl3ProgressModal
              @is_locked={{this.lockedStatus.is_locked}}
              @locked_at_trust_level={{this.lockedStatus.locked_at_trust_level}}
              @stats={{this.stats}}
              @user={{@user}}
            />
          </DModal>
        {{/if}}
      {{/if}}
    {{/if}}
  </template>
}
