extends GutTest

func test_transmission_types_then_holds_before_expiring() -> void:
	var playback: RadioPlayback = RadioPlayback.new()
	playback.start("A".repeat(340))
	assert_eq(playback.characters(),0)
	playback.advance(5)
	assert_eq(playback.characters(),170)
	assert_gt(playback.remaining(),5.0)
	playback.advance(5)
	assert_eq(playback.characters(),340)
	assert_gt(playback.remaining(),0.0,"Typing does not consume the reading interval.")
	playback.advance(100)
	assert_eq(playback.remaining(),0.0)

func test_static_accessible_transmission_still_gets_reading_time() -> void:
	var playback: RadioPlayback = RadioPlayback.new()
	playback.start("Full transcript",false)
	assert_eq(playback.characters(),"Full transcript".length())
	assert_eq(playback.remaining(),6.0)
	assert_eq(playback.advance(-1),ERR_INVALID_PARAMETER)
	assert_eq(playback.advance(NAN),ERR_INVALID_PARAMETER)
	assert_eq(playback.remaining(),6.0)

func test_clock_is_consistent_at_30_60_120_steps() -> void:
	for rate: int in [30,60,120]:
		var playback: RadioPlayback = RadioPlayback.new()
		playback.start("A".repeat(170))
		for step: int in range(rate*3): playback.advance(1.0/rate)
		assert_between(playback.characters(),101,102)
		assert_almost_eq(playback.elapsed,3.0,0.000001)
