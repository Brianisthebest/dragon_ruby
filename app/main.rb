module Main
  FPS = 60

  def spawn_target(args)
    size = 64
    {
      x: rand(args.grid.w * 0.4) + args.grid.w * 0.6 - size,
      y: rand(args.grid.h - size * 2) + size - 64,
      w: size,
      h: size,
      path: 'sprites/misc/target.png',
      points: 1
    }
  end

  def spawn_gold_target(args)
    size = 64

    {
      x: rand(args.grid.w * 0.4) + args.grid.w * 0.6 - size,
      y: rand(args.grid.h - size * 2) + size - 64,
      w: size,
      h: size,
      base_size: size,
      path: "sprites/misc/golden-target.png",
      points: 5,
      born_at: Kernel.tick_count
    }
  end

  def spawn_cloud(args)
    {
      x: args.grid.w,
      y: rand(args.grid.h - 250),
      w: 300,
      h: 250,
      speed: Numeric.rand(7..20),
      path: "sprites/misc/cloud#{Numeric.rand(1..3)}.png"
    }
  end

  def spawn_explosion(x, y)
    size = 64
    {
      x: x,
      y: y,
      h: size,
      w: size,
      born_at: Kernel.tick_count,
      path: "sprites/misc/explosion-0.png"
    }
  end

  def fire_input?(args)
    args.inputs.keyboard.key_down.z ||
      args.inputs.keyboard.key_down.j ||
      args.inputs.controller_one.key_down.a
  end

  def handle_player_movement(args)
    if args.inputs.left
      args.state.player.x -= args.state.player.speed
    elsif args.inputs.right
      args.state.player.x += args.state.player.speed
    end

    if args.inputs.up
      args.state.player.y += args.state.player.speed
    elsif args.inputs.down
      args.state.player.y -= args.state.player.speed
    end

    if args.state.player.x +  args.state.player.w > args.grid.w
      args.state.player.x = args.grid.w - args.state.player.w
    end

    if args.state.player.x < 0
      args.state.player.x = 0
    end

    if args.state.player.y + args.state.player.h > args.grid.h
      args.state.player.y = args.grid.h - args.state.player.h
    end

    if args.state.player.y < 0
      args.state.player.y = 0
    end
  end

  def play_music(args, song)
    current = args.audio[:music]

    return if current && current.input == song && !current.paused

    args.audio[:music] = {
      input: song,
      looping: true
    }
  end

  HIGH_SCORE_FILE = "high-score.txt"

  def game_over_tick(args)
    args.state.high_score ||= DR.read_file(HIGH_SCORE_FILE).to_i

    args.state.timer -= 1

    if !args.state.saved_high_score && args.state.score > args.state.high_score
      DR.write_file(HIGH_SCORE_FILE, args.state.score.to_s)
      args.state.saved_high_score = true
    end

    labels = []
    labels << {
      x: 40,
      y: args.grid.h - 40,
      text: "Game Over!",
      size_px: 42,
    }
    labels << {
      x: 40,
      y: args.grid.h - 90,
      text: "Score: #{args.state.score}",
      size_px: 30,
    }
    labels << {
      x: 40,
      y: args.grid.h - 132,
      text: "Fire to restart",
      size_px: 26,
    }

    if args.state.score > args.state.high_score
      labels << {
        x: 260,
        y: args.grid.h - 90,
        text: "New high-score!",
        size_px: 28,
      }
    else
      labels << {
        x: 260,
        y: args.grid.h - 90,
        text: "Score to beat: #{args.state.high_score}",
        size_px: 28,
      }
    end


    args.outputs.labels << labels

    if args.state.timer < -30 && fire_input?(args)
      DR.reset
    end
  end

  def gameplay_tick(args)
    if args.inputs.keyboard.key_down.p
      args.state.paused = !args.state.paused
    end

    args.state.shake ||= 0

    shake_x = 0
    shake_y = 0

    if args.state.shake > 0
      shake_x = Numeric.rand(-args.state.shake..args.state.shake)
      shake_y = Numeric.rand(-args.state.shake..args.state.shake)

      args.state.shake -= 1
    end

    if args.state.paused
      paused_tick(args)
      return
    end

    args.outputs.solids << {
      x: shake_x,
      y: shake_y,
      w: args.grid.w,
      h: args.grid.h,
      r: 92,
      g: 120,
      b: 230,
    }

    args.state.player ||= {
      x: 120,
      y: 280,
      w: 100,
      h: 80,
      speed: 12
    }

    player_sprite_index = 0.frame_index(count: 6, hold_for: 6, repeat: true)
    args.state.player.path = "sprites/misc/dragon-#{player_sprite_index}.png"

    args.state.fireballs ||= []
    args.state.targets ||= [
      spawn_target(args), spawn_target(args), spawn_target(args)
    ]
    args.state.clouds ||= [
      spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args)
    ]

    args.state.explosions ||= []

    args.state.score ||= 0
    args.state.timer ||= 20 * FPS

    args.state.timer -= 1

    if args.state.timer.zero?
      args.audio.delete(:music)
      args.outputs.sounds << "sounds/game-over.wav"
      args.state.scene = "game_over"
      return
    end

    if args.state.timer.negative?
      game_over_tick(args)
      return
    end

    handle_player_movement(args)

    args.state.next_gold_spawn ||= Kernel.tick_count + Numeric.rand(480..900)

    if Kernel.tick_count >= args.state.next_gold_spawn &&
      args.state.targets.none? { |t| t.points == 5 }

      args.state.targets << spawn_gold_target(args)

      args.state.next_gold_spawn =
        Kernel.tick_count + Numeric.rand(480..900)
    end

    if fire_input?(args)
      args.outputs.sounds << "sounds/fireball.wav"
      args.state.fireballs << {
        x: args.state.player.x + args.state.player.w - 12,
        y: args.state.player.y + 10,
        w: 32,
        h: 32,
        start_y: args.state.player.y + 10,
        born_at: Kernel.tick_count,
        path: 'sprites/misc/fireball.png',
      }
    end

    args.state.clouds.each do |cloud|
      cloud.x -= cloud.speed
      cloud_len = cloud.x + cloud.w

      if cloud_len.negative?
        cloud.dead = true
        args.state.clouds << spawn_cloud(args)
        next
      end
    end

    args.state.fireballs.each do |fireball|
      fireball.x += args.state.player.speed + 2

      age = Kernel.tick_count - fireball.born_at

      fireball.y = fireball.start_y + Math.sin(age * 0.3) * 5

      if fireball.x > args.grid.w
        fireball.dead = true
        next
      end

      args.state.targets.each do |target|
        if args.geometry.intersect_rect?(target, fireball)
          args.outputs.sounds << "sounds/target.wav"
          target.dead = true
          fireball.dead = true
          if target.points == 1
            args.state.score += target.points
            args.state.targets << spawn_target(args)
          end
          args.state.explosions << spawn_explosion(target.x, target.y)

          args.state.shake = 8
        end
      end
    end

    args.state.targets.each do |target|
      next unless target.points == 5

      pulse = Math.sin(Kernel.tick_count * 0.25) * 6

      target.w = target.base_size + pulse
      target.h = target.base_size + pulse

      target.y += 5

      if target.y > args.grid.h + target.base_size
        target.y = 0 - target.base_size
      end

      if Kernel.tick_count - target.born_at > 300
        target.dead = true
      end
    end

    args.state.explosions.each do |explosion|
      age = Kernel.tick_count - explosion.born_at
      sprite_index = age.idiv(4)

      if sprite_index >= 6
        explosion.dead = true
      else
        explosion.path = "sprites/misc/explosion-#{sprite_index}.png"
      end
    end

    args.state.targets.reject! { |t| t.dead }
    args.state.fireballs.reject! { |f| f.dead }
    args.state.clouds.reject! { |c| c.dead }
    args.state.explosions.reject! { |e| e.dead }
    sprites = []

    [
      args.state.clouds,
      [args.state.player],
      args.state.fireballs,
      args.state.explosions,
      args.state.targets
    ].flatten.each do |sprite|
      sprites << sprite.merge(
        x: sprite.x + shake_x,
        y: sprite.y + shake_y
      )
    end

    args.outputs.sprites << sprites

    labels = []
    labels << {
      x: 40,
      y: args.grid.h - 40,
      text: "Score: #{args.state.score}",
      size_px: 30,
    }
    labels << {
      x: args.grid.w - 40,
      y: args.grid.h - 40,
      text: "Time Left: #{(args.state.timer / FPS).round}",
      size_px: 26,
      anchor_x: 1,
    }
    args.outputs.labels << labels
  end

  def paused_tick(args)
    args.outputs.solids << {
      x: 0,
      y: 0,
      w: args.grid.w,
      h: args.grid.h,
      r: 0,
      g: 0,
      b: 0,
      a: 180
    }

    args.outputs.labels << {
      x: args.grid.w / 2,
      y: args.grid.h / 2 + 40,
      text: "Paused",
      size_px: 40,
      anchor_x: 0.5
    }

    args.outputs.labels << {
      x: args.grid.w / 2,
      y: args.grid.h / 2,
      text: "Press P to Resume",
      size_px: 24,
      anchor_x: 0.5
    }
  end

  def title_tick(args)
    if fire_input?(args)
      args.outputs.sounds << "sounds/game-over.wav"
      args.state.scene = "gameplay"
      return
    end

    args.state.high_score ||= DR.read_file(HIGH_SCORE_FILE).to_i

    labels = []
    labels << {
      x: 40,
      y: args.grid.h - 40,
      text: "Target Practice",
      size_px: 34,
    }
    labels << {
      x: 40,
      y: args.grid.h - 88,
      text: "Hit the targets!",
    }
    labels << {
      x: 40,
      y: args.grid.h - 120,
      text: "by brianistheworst",
    }
    labels << {
      x: 40,
      y: 120,
      text: "Arrows or WASD to move | Z or J to fire | P to pause | gamepad works too",
    }
    labels << {
      x: 40,
      y: 80,
      text: "Fire to start",
      size_px: 26,
    }
    labels << {
      x: 40,
      y: args.grid.h - 155,
      text: "Score to beat: #{args.state.high_score}",
      size_px: 28,
    }

    args.state.player ||= {
      x: 120,
      y: 280,
      w: 100,
      h: 80,
      speed: 12
    }

    args.outputs.sprites << {
      x: -20,
      y: 225, 
      w: 350,
      h: 350,
      path: 'sprites/misc/title_dragon.png'

    }
    args.outputs.labels << labels
  end

  def tick(args)
    args.state.scene ||= "title"

    if args.state.previous_scene != args.state.scene
      case args.state.scene
      when "title"
        play_music(args, "sounds/title-music.mp3")
      when "gameplay"
        play_music(args,  "sounds/flight.ogg")
      end

      args.state.previous_scene = args.state.scene
    end

    send("#{args.state.scene}_tick", args)
  end
end

DR.reset