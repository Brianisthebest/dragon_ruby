module Main
  FPS = 60

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

  def level_transition_tick(args)
    elapsed = Kernel.tick_count - args.state.level_transition_started_at

    args.outputs.solids << {
      x: 0,
      y: 0,
      w: args.grid.w,
      h: args.grid.h,
      r: 10,
      g: 100,
      b: 10
    }

    args.outputs.labels << {
      x: args.grid.w / 2 - 200,
      y: args.grid.h / 2 + 20,
      text: "Get Ready for Level #{args.state.next_level}!",
      size_px: 40
    }

    if elapsed > 5 * FPS
      args.state.targets = []
      args.state.fireballs = []
      args.state.clouds = nil
      args.state.explosions = []
      args.state.level += 1

      args.state.scene = "level_#{args.state.next_level}"
    end
  end

  def level_1_tick(args)
    pause_game(args)

    args.state.shake ||= 0
    args.state.level ||= 1

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
    args.state.targets ||= []

    if args.state.targets.empty?
      3.times do
        args.state.targets << spawn_target(args, args.state.targets)
      end
    end

    args.state.clouds ||= [
      spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args), spawn_cloud(args)
    ]
    args.state.explosions ||= []

    args.state.score ||= 0
    args.state.timer ||= 5 * FPS

    args.state.timer -= 1

    if args.state.timer.zero?
      args.audio.delete(:music)
      args.outputs.sounds << "sounds/next-level.mp3"
      args.state.scene = "level_transition"
      args.state.next_level = args.state.level + 1
      args.state.level_transition_started_at = Kernel.tick_count
      return
    end

    if args.state.timer.negative?
      game_over_tick(args)
      return
    end

    handle_player_movement(args)

    args.state.next_gold_spawn ||= Kernel.tick_count + Numeric.rand(480..900)

    if Kernel.tick_count >= args.state.next_gold_spawn && args.state.targets.none? { |t| t.points == 5 }
      args.state.targets << spawn_gold_target(args)
      args.outputs.sounds << "sounds/bonus.mp3"
      args.state.next_gold_spawn = Kernel.tick_count + Numeric.rand(480..900)
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

    update_clouds(args)
    update_fireballs_and_targets(args)
    update_golden_targets(args)
    update_explosions(args)

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

  def level_2_tick(args)
    pause_game(args)

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
      r: 0,
      g: 0,
      b: 0,
    }

    args.outputs.sprites << {
      x: args.grid.w - 230,
      y: args.grid.h - 230, 
      w: 135,
      h: 135,
      path: 'sprites/misc/Lava.png'

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

    args.state.player_health ||= 5
    args.state.enemy_fireballs ||= []
    args.state.fireballs ||= []
    args.state.enemies ||= []

    if args.state.enemies.empty?
      3.times do
        args.state.enemies << spawn_enemy(args, args.state.enemies)
      end
    end

    args.state.stars ||= []
    
    if args.state.stars.empty?
      1500.times do
        args.state.stars << spawn_star(args)
      end
    end

    args.state.enemy_explosions ||= []

    args.state.score ||= 0
    args.state.level_2_timer ||= 20 * FPS

    args.state.level_2_timer -= 1

    if args.state.level_2_timer.zero?
      args.audio.delete(:music)
      args.outputs.sounds << "sounds/game-over.mp3"
      args.state.scene = "game_over"
      return
    end

    if args.state.timer.negative?
      game_over_tick(args)
      return
    end

    handle_player_movement(args)

    args.state.next_gold_spawn ||= Kernel.tick_count + Numeric.rand(480..900)

    if Kernel.tick_count >= args.state.next_gold_spawn && args.state.targets.none? { |t| t.points == 5 }
      args.state.targets << spawn_gold_target(args)
      args.outputs.sounds << "sounds/bonus.mp3"
      args.state.next_gold_spawn = Kernel.tick_count + Numeric.rand(480..900)
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

    update_stars(args)
    update_enemies(args)
    update_fireballs_and_enemies(args)
    update_enemy_fireballs(args)
    update_enemy_explosions(args)

    if args.state.player_health <= 0
      args.audio.delete(:music)
      args.outputs.sounds << "sounds/game-over.mp3"
      args.state.scene = "game_over"
      return
    end

    args.state.enemies.reject! { |e| e.dead }
    args.state.fireballs.reject! { |f| f.dead }
    args.state.enemy_fireballs.reject! { |f| f.dead }
    args.state.stars.reject! { |c| c.dead }
    args.state.enemy_explosions.reject! { |e| e.dead }
    sprites = []

    [
      [args.state.player],
      args.state.fireballs,
      args.state.enemy_explosions,
      args.state.enemies,
      args.state.enemy_fireballs
    ].flatten.each do |sprite|
      sprites << sprite.merge(
        x: sprite.x + shake_x,
        y: sprite.y + shake_y
      )
    end

    args.outputs.sprites << sprites
    args.outputs.solids << args.state.stars.reject(&:dead)

    labels = []
    labels << {
      x: args.grid.w / 2,
      y: args.grid.h - 40,
      text: "Health: #{args.state.player_health}",
      size_px: 25,
      anchor_x: 0.5,
      r: 255,
      g: 255,
      b: 255
    } 
    labels << {
      x: 40,
      y: args.grid.h - 40,
      text: "Score: #{args.state.score}",
      size_px: 30,
      r: 255,
      g: 255,
      b: 255
    }
    labels << {
      x: args.grid.w - 40,
      y: args.grid.h - 40,
      text: "Time Left: #{(args.state.level_2_timer / FPS).round}",
      size_px: 26,
      anchor_x: 1,
      r: 255,
      g: 255,
      b: 255
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
      args.outputs.sounds << "sounds/game-over.mp3"
      args.state.scene = "level_1"
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
      when "level_1"
        play_music(args,  "sounds/flight.mp3")
      when "level_2"
        play_music(args,  "sounds/space.mp3")
      end

      args.state.previous_scene = args.state.scene
    end

    send("#{args.state.scene}_tick", args)
  end
end

private

  def pause_game(args)
    if args.inputs.keyboard.key_down.p
      args.state.paused = !args.state.paused
    end
  end

  def spawn_target(args, existing_targets)
    size = 64

    loop do
      target = {
        x: rand(args.grid.w * 0.4) + args.grid.w * 0.6 - size,
        y: rand(args.grid.h - size * 2) + size - 64,
        w: size,
        h: size,
        path: 'sprites/misc/target.png',
        points: 1
      }

      overlapping = existing_targets.any? do |other|
        args.geometry.intersect_rect?(target, other)
      end

      return target unless overlapping
    end
  end

  def spawn_enemy(args, existing_enemies)
    size = 128

    loop do
      enemy = {
        x: rand(args.grid.w * 0.4) + args.grid.w * 0.6 - size,
        y: rand(args.grid.h - size * 2) + size - 64,
        w: size,
        h: size,
        path: 'sprites/misc/enemies.png',
        angle: 90,
        points: 1,
        animate_frame_count: 28,
        born_at: Kernel.tick_count
      }

      overlapping = existing_enemies.any? do |other|
        args.geometry.intersect_rect?(enemy, other)
      end

      return enemy unless overlapping
    end
  end

  def update_fireballs_and_enemies(args)
    args.state.fireballs.each do |fireball|
      fireball.x += args.state.player.speed + 2

      age = Kernel.tick_count - fireball.born_at

      fireball.y = fireball.start_y + Math.sin(age * 0.3) * 5

      if fireball.x > args.grid.w
        fireball.dead = true
        next
      end

      args.state.enemies.each do |enemy|
        if args.geometry.intersect_rect?(enemy, fireball)
          args.outputs.sounds << "sounds/target.wav"
          enemy.dead = true
          fireball.dead = true
          args.state.score += enemy.points
          args.state.enemies << spawn_enemy(args, args.state.enemies)
          args.state.enemy_explosions << spawn_enemy_explosion(enemy.x, enemy.y)
          args.state.shake = 8
        end
      end
    end
  end

  def update_enemies(args)
    args.state.enemies.each do |enemy|
      update_enemy_animations(args, enemy)
      fire_enemy_fireballs(args, enemy)
    end
  end

  def fire_enemy_fireballs(args, enemy)
    enemy.next_fire_at ||= Kernel.tick_count + Numeric.rand(90..180)

    if Kernel.tick_count >= enemy.next_fire_at
      args.outputs.sounds << "sounds/fireball.wav"
      args.state.enemy_fireballs << spawn_enemy_fireball(enemy)
      enemy.next_fire_at = Kernel.tick_count + Numeric.rand(120..240)
    end
  end

  def spawn_enemy_fireball(enemy)
    {
      x: enemy.x,
      y: enemy.y + enemy.h / 2 - 32,
      w: 36,
      h: 64,
      start_y: enemy.y + enemy.h / 2 - 64,
      born_at: Kernel.tick_count,
      path: 'sprites/misc/rocket.png',
      animate_frame_count: 4,
      tile_x: 0,
      tile_y: 0,
      tile_w: 9,
      tile_h: 16,
      angle: 90
    }
  end

  def update_enemy_fireballs(args)
    args.state.enemy_fireballs.each do |fireball|
      fireball.x -= 10

      frame_index = fireball.born_at.frame_index(
        count: fireball.animate_frame_count,
        hold_for: 4,
        repeat: true
      )
      fireball.tile_x = frame_index * 9

      if fireball.x + fireball.w < 0
        fireball.dead = true
        next
      end
      if args.geometry.intersect_rect?(args.state.player, fireball)
        fireball.dead = true
        args.state.player_health -= 1
        args.outputs.sounds << "sounds/target.wav"
        args.state.shake = 8
      end
    end
  end

  def update_enemy_animations(args, enemy)
    frame_index = enemy.born_at.frame_index(
      count: enemy.animate_frame_count,
      hold_for: 4,
      repeat: true
    )

    enemy.tile_x = frame_index * 64
    enemy.tile_y = 0
    enemy.tile_w = 64
    enemy.tile_h = 64
  end

  def update_fireballs_and_targets(args)
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
            args.state.targets << spawn_target(args, args.state.targets)
          else
            args.state.score += target.points
          end

          args.state.explosions << spawn_explosion(target.x, target.y)

          args.state.shake = 8
        end
      end
    end
  end

  def spawn_gold_target(args)
    size = 64
    {
      x: rand(args.grid.w * 0.4) + args.grid.w * 0.6 - size,
      y: rand(args.grid.h - size * 2) + size - 64,
      w: size,
      h: size,
      base_size: size,
      y_speed: 5,
      x_speed: 3,
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

  def spawn_star(args)
    size = Numeric.rand(1..3)
    brightness = Numeric.rand(120..255)

    {
      x: rand(args.grid.w) + 450,
      y: rand(args.grid.h),
      w: size,
      h: size,
      speed: Numeric.rand(2..10),
      r: brightness,
      g: brightness,
      b: brightness
    }
  end

  def update_clouds(args)
    args.state.clouds.each do |cloud|
      cloud.x -= cloud.speed
      cloud_len = cloud.x + cloud.w

      if cloud_len.negative?
        cloud.dead = true
        args.state.clouds << spawn_cloud(args)
        next
      end
    end
  end

  def update_stars(args)
    args.state.stars.each do |star|
      star.x -= star.speed

      if star.x + star.w < 0
        star.dead = true
        args.state.stars << spawn_star(args)
        next
      end
    end
  end

  def update_golden_targets(args)
    args.state.targets.each do |target|
      next unless target.points == 5

      pulse = Math.sin(Kernel.tick_count * 0.25) * 6

      target.w = target.base_size + pulse
      target.h = target.base_size + pulse

      target.y += target.y_speed
      target.x += target.x_speed

      left_limit = args.grid.w * 0.6

      if target.x <= left_limit
        target.x = left_limit
        target.x_speed *= -1
      elsif target.x >= args.grid.w - target.w
        target.x = args.grid.w - target.w
        target.x_speed *= -1
      end

      if target.y >= args.grid.h - target.h
        target.y = args.grid.h - target.h
        target.y_speed *= -1
      elsif target.y <= 0
        target.y = 0
        target.y_speed *= -1
      end

      if Kernel.tick_count - target.born_at > 300
        target.dead = true
      end
    end
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

  def spawn_enemy_explosion(x, y)
    size = 64
    {
      x: x,
      y: y,
      h: size,
      w: size,
      angle: 90,
      born_at: Kernel.tick_count,
      path: "sprites/misc/enemies-explode.png",
      tile_x: 0,
      tile_y: 0,
      tile_w: 64,
      tile_h: 64
    }
  end

  def update_explosions(args)
    args.state.explosions.each do |explosion|
      age = Kernel.tick_count - explosion.born_at
      sprite_index = age.idiv(4)

      if sprite_index >= 6
        explosion.dead = true
      else
        explosion.path = "sprites/misc/explosion-#{sprite_index}.png"
      end
    end
  end

  def update_enemy_explosions(args)
    args.state.enemy_explosions.each do |explosion|
      age = Kernel.tick_count - explosion.born_at
      frame_index = age.idiv(4)

      if frame_index >= 18
        explosion.dead = true
      else
        explosion.tile_x = frame_index * 64
      end
    end
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

DR.reset