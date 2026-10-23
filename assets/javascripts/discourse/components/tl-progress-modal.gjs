import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { and, notEq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { doesQualify } from "../lib/calculate-stats.js";
import shouldShow from "../lib/should-show.js";
import ProgressBar from "./progress-bar.gjs";

export default class Tl3ProgressModal extends Component {
  @service siteSettings;

  get stats() {
    return this.args.stats;
  }

  get suspended_before() {
    const logic =
      this.stats["penalty_counts"]["suspended"] > 0 || this.stats["suspended"];
    return {
      data: logic,
      style: `color: ${logic ? "var(--danger)" : "var(--success)"}`,
    };
  }

  get silenced_before() {
    const logic =
      this.stats["penalty_counts"]["silenced"] > 0 || this.stats["silenced"];
    return {
      data: logic,
      style: `color: ${logic ? "var(--danger)" : "var(--success)"}`,
    };
  }

  get doesQualify() {
    return doesQualify(this.stats);
  }

  get doesQualifyStyle() {
    return `color: ${this.doesQualify ? "var(--success)" : "var(--danger)"};`;
  }

  get timePeriodText() {
    return i18n("see_tl_progress.time_period", {
      num_days: this.stats.time_period,
    });
  }

  get modalBottomText() {
    return this.siteSettings[
      `modal_bottom_text_tl${this.stats.trust_level}`
    ] !== ""
      ? {
          show: true,
          text: this.siteSettings[
            `modal_bottom_text_tl${this.stats.trust_level}`
          ],
        }
      : {
          show: false,
          text: "",
        };
  }

  <template>
    {{#if @stats}}
      <p class="inline-wrapper">
        <div style={{trustHTML this.suspended_before.style}}>
          {{dIcon (if this.suspended_before.data "xmark" "check")}}
        </div>

        {{i18n
          (if
            this.suspended_before.data
            "see_tl_progress.suspended"
            "see_tl_progress.not_suspended"
          )
        }}</p>

      <p class="inline-wrapper">
        <div style={{trustHTML this.silenced_before.style}}>
          {{dIcon (if this.silenced_before.data "xmark" "check")}}
        </div>

        {{i18n
          (if
            this.silenced_before.data
            "see_tl_progress.silenced"
            "see_tl_progress.not_silenced"
          )
        }}</p>

      <div class="all-progress-gauges">
        {{#each-in @stats as |key stat|}}
          {{#if (shouldShow key)}}
            <ProgressBar
              @id={{key}}
              @title={{concat "see_tl_progress." key}}
              @total={{stat.req}}
              @type={{if stat.max "max" "min"}}
              @value={{stat.value}}
            />
          {{/if}}
        {{/each-in}}
      </div>

      <hr />

      <p class="inline-wrapper tl3-promotion-decision">
        {{#if this.doesQualify}}
          {{#if @is_locked}}
            {{dIcon "lock"}}
            {{i18n "see_tl_progress.locked_will_not_be_promoted"}}
          {{else}}
            {{#if (notEq @user.trust_level @stats.trust_level)}}
              {{dIcon "check"}}
              {{i18n
                "see_tl_progress.qualifies"
                trust_level=@stats.trust_level
              }}
              {{i18n "see_tl_progress.will_be_promoted"}}
            {{else}}
              {{dIcon "check"}}
              {{i18n
                "see_tl_progress.qualifies"
                trust_level=@stats.trust_level
              }}
            {{/if}}
          {{/if}}
        {{else}}
          {{#if (eq @user.trust_level 3)}}
            {{#if (and @is_locked (eq @locked_at_trust_level 3))}}
              {{! User is TL3, and is locked at TL3 }}
              {{dIcon "lock"}}
              {{i18n "see_tl_progress.locked_will_not_be_demoted"}}
            {{else}}
              {{#if @stats.on_grace_period}}
                {{dIcon "check"}}
                {{i18n "see_tl_progress.on_grace_period"}}
              {{else}}
                {{dIcon "xmark"}}
                {{i18n "see_tl_progress.will_be_demoted"}}
              {{/if}}
            {{/if}}
          {{else}}
            {{! User is not TL3 and does not qualify }}
            {{dIcon "xmark"}}
            {{i18n
              "see_tl_progress.does_not_qualify"
              trust_level=@stats.trust_level
            }}
          {{/if}}
        {{/if}}
      </p>
    {{/if}}

    {{#if this.modalBottomText.show}}
      <hr />
      <p>{{trustHTML this.modalBottomText.text}}</p>
    {{/if}}
  </template>
}
