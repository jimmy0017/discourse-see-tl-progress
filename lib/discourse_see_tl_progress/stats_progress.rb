# frozen_string_literal: true

module DiscourseSeeTlProgress
  class StatsProgress
    def initialize(user)
      @user = user
      @stat = user.user_stat
      @pc = TrustLevel3Requirements.new(user)
    end

    def stats
      case @user.trust_level
      when 0
        tl1_stats
      when 1
        tl2_stats
      when 2, 3
        # TL3 users get the same TL3 stats so they can track whether they keep TL3
        tl3_stats
      else
        {}
      end
    end

    # TL0 -> TL1
    def tl1_stats
      {
        trust_level: 1,
        tl1_met: Promotion.tl1_met?(@user),
        penalty_counts: @pc.penalty_counts,
        topics_entered: {
          value: @stat.topics_entered,
          req: SiteSetting.tl1_requires_topics_entered,
          max: false,
        },
        posts_read: {
          value: @stat.posts_read_count,
          req: SiteSetting.tl1_requires_read_posts,
          max: false,
        },
        time_read: {
          value: @stat.time_read / 60,
          req: SiteSetting.tl1_requires_time_spent_mins,
          max: false,
        },
        account_existed_time: {
          value: (Time.now - @user.created_at) / 60,
          req: SiteSetting.tl1_requires_time_spent_mins,
          max: false,
        },
      }
    end

    # TL1 -> TL2
    def tl2_stats
      {
        trust_level: 2,
        tl2_met: Promotion.tl2_met?(@user),
        penalty_counts: @pc.penalty_counts,
        days_visited: {
          value: @stat.days_visited,
          req: SiteSetting.tl2_requires_days_visited,
          max: false,
        },
        topics_entered: {
          value: @stat.topics_entered,
          req: SiteSetting.tl2_requires_topics_entered,
          max: false,
        },
        posts_read: {
          value: @stat.posts_read_count,
          req: SiteSetting.tl2_requires_read_posts,
          max: false,
        },
        time_read: {
          value: @stat.time_read / 60,
          req: SiteSetting.tl2_requires_time_spent_mins,
          max: false,
        },
        account_existed_time: {
          value: (Time.now - @user.created_at) / 60,
          req: SiteSetting.tl2_requires_time_spent_mins,
          max: false,
        },
        likes_given: {
          value: @stat.likes_given,
          req: SiteSetting.tl2_requires_likes_given,
          max: false,
        },
        likes_received: {
          value: @stat.likes_received,
          req: SiteSetting.tl2_requires_likes_received,
          max: false,
        },
        min_topics_replied_to: {
          value: @stat.calc_topic_reply_count!,
          req: SiteSetting.tl2_requires_topic_reply_count,
          max: false,
        },
      }
    end

    # TL2 -> TL3
    def tl3_stats
      # For users already at TL3, "met" means they keep TL3: core only demotes when
      # requirements_lost? (stats below LOW_WATER_MARK, i.e. 90% of the requirements).
      met = @user.trust_level >= 3 ? !@pc.requirements_lost? : Promotion.tl3_met?(@user)

      { trust_level: 3, tl3_met: met }.merge(DiscourseSeeTlProgress::TL3Stats.new(@user).stats)
    end
  end
end
