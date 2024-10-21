/**
 * The CLIK ScrollIndicator displays the scroll position of another component, such as a multiline textField. It can be pointed at a textField to automatically display its scroll position. All list-based components as well as the TextArea have a scrollBar property which can be pointed to a ScrollIndicator or ScrollBar instance or linkage ID.

	<b>Inspectable Properties</b>
	The inspectable properties of the ScrollIndicator are:<ul>
	<li><i>scrollTarget</i>: Set a TextArea or normal multiline textField as the scroll target to automatically respond to scroll events. Non-text field types have to manually update the ScrollIndicator properties.</li>
	<li><i>visible</i>: Hides the component if set to false.</li>
	<li><i>disabled</i>: Disables the component if set to true.</li>
	<li><i>offsetTop</i>: Thumb offset at the top. A positive value moves the thumb's top-most position higher.</li>
	<li><i>offsetBottom</i>: Thumb offset at the bottom. A positive value moves the thumb's bottom-most position lower.</li>
	<li><i>enableInitCallback</i>: If set to true, _global.CLIK_loadCallback() will be fired when a component is loaded and _global.CLIK_unloadCallback will be called when the component is unloaded. These methods receive the instance name, target path, and a reference the component as parameters.  _global.CLIK_loadCallback and _global.CLIK_unloadCallback should be overridden from the game engine using GFx FunctionObjects.</li>
	<li><i>soundMap</i>: Mapping between events and sound process. When an event is fired, the associated sound process will be fired via _global.gfxProcessSound, which should be overridden from the game engine using GFx FunctionObjects.</li></ul>

	<b>States</b>
	The ScrollIndicator does not have explicit states. It uses the states of its child elements, the thumb and track Button components.

	<b>Events</b>
	All event callbacks receive a single Object parameter that contains relevant information about the event. The following properties are common to all events. <ul>
	<li><i>type</i>: The event type.</li>
	<li><i>target</i>: The target that generated the event.</li></ul>

	The events generated by the ScrollIndicator component are listed below. The properties listed next to the event are provided in addition to the common properties.<ul>
	<li><i>show</i>: The component’s visible property has been set to true at runtime.</li>
	<li><i>hide</i>: The component’s visible property has been set to false at runtime.</li>
	<li><i>scroll</i>: The scroll position has changed.<ul>
		<li><i>position</i>: The new scroll position. Number type. Values minimum position to maximum position. </li></ul></li></ul>
 */


import gfx.controls.Button;
import gfx.core.UIComponent;


[InspectableList("disabled", "visible", "inspectableScrollTarget", "offsetTop", "offsetBottom", "enableInitCallback", "soundMap")]
class gfx.controls.ScrollIndicator extends UIComponent
{
	/* PUBLIC VARIABLES */

	/** Whether the component is horizontal or vertical. This property is auto-set on stage components based on their rotation. */
	public var direction: String = "vertical";
	/** Mapping between events and sound process */
	[Inspectable(type="Object", defaultValue="theme:default,scroll:scroll")]
	public var soundMap: Object = { theme:"default", scroll:"scroll" };


	/* PRIVATE VARIABLES */

	private var pageSize: Number;
	private var pageScrollSize: Number = 1;
	private var minPosition: Number = 0;
	private var maxPosition: Number = 10;
	private var _position: Number = 5;
	private var _scrollTarget: Object;
	[Inspectable(type="String", name="scrollTarget")]
	private var inspectableScrollTarget: Object;
	[Inspectable(defaultValue="0", verbose=1)]
	private var offsetTop: Number = 0;
	[Inspectable(defaultValue="0", verbose=1)]
	private var offsetBottom: Number = 0;
	private var lastVScrollPos: Number;
	private var scrollerIntervalID: Number;
	private var isDragging: Boolean = false;
	private var scrollTargetSelection: Array;


	/* STAGE ELEMENTS */

	/** A reference to the thumb symbol in the ScrollIndicator. */
	public var thumb: Button;
	/** A reference to the track symbol in the ScrollIndicator. */
	public var track: MovieClip;


	/* INITIALIZATION */

	/**
	 * The constructor is called when a ScrollIndicator or a sub-class of ScrollIndicator is instantiated on stage or by using {@code attachMovie()} in ActionScript. This component can <b>not</b> be instantiated using {@code new} syntax. When creating new components that extend ScrollIndicator, ensure that a {@code super()} call is made first in the constructor.
	 */
	public function ScrollIndicator()
	{
		super();
		tabChildren = false;
		focusEnabled = tabEnabled = !_disabled;
	}


	/* PUBLIC FUNCTIONS */

	/**
	 * Disable this component.
	 */
	[Inspectable(defaultValue="false")]
	public function get disabled(): Boolean
	{
		return _disabled;
	}


	public function set disabled(value: Boolean): Void
	{
		if (_disabled == value) {
			return;
		}

		super.disabled = value;
		focusEnabled = tabEnabled = !_disabled;
		if (_scrollTarget) {
			tabEnabled = false;
		}

		if (initialized) {
			thumb.disabled = _disabled;
		}
	}


	/**
	 * Set the scroll properties of the component.
	 * @param pageSize The size of the pages to determine scroll distance.
	 * @param minPosition The minimum scroll position.
	 * @param maxPosition The maximum scroll position.
	 * @param pageScrollSize The amount to scroll when "paging". Not currently implemented.
	 */
	public function setScrollProperties(pageSize: Number, minPosition: Number, maxPosition: Number, pageScrollSize: Number): Void
	{
		this.pageSize = pageSize;
		if (pageScrollSize != undefined) {
			this.pageScrollSize = pageScrollSize;
		}

		this.minPosition = minPosition;
		this.maxPosition = maxPosition;
		updateThumb();
	}


	/**
	 * Set the scroll position to a number between the minimum and maximum.
	 */
	public function get position(): Number
	{
		return _position;
	}


	public function set position(value: Number): Void
	{
		if (value == _position) {
			return;
		}

		_position = Math.max(minPosition, Math.min(maxPosition, value));
		dispatchEventAndSound({type: "scroll", position: _position});
		invalidate();
	}


	/**
	 * Manually update the scrollBar when the target changes.
	 */
	public function update(): Void
	{
		//onScoller();
	}


	/**
	 * Set a text target for the ScrollIndicator to respond to scroll changes.
	 	Non-text fields have to manually update the properties.
	 */
	public function get scrollTarget(): Object
	{
		return _scrollTarget;
	}


	public function set scrollTarget(value: Object): Void
	{
		//if (_scrollTarget == value) { return; }
		var _prevScrollTarget: Object = _scrollTarget;
		_scrollTarget = value;

		if (_prevScrollTarget && (value._parent != _prevScrollTarget)) {
			_prevScrollTarget.removeListener(this);
			if (_prevScrollTarget.scrollBar != null) {
				_prevScrollTarget.scrollBar = null;
			}

			focusTarget = null;
			_prevScrollTarget.noAutoSelection = false;
		}

		// Check if the scrollTarget is one a component, and if it has a scrollBar property (like a List)
		if (value instanceof UIComponent && value.scrollBar !== null) {
			value.scrollBar = this;
			return;
		}

		if (_scrollTarget == null) {
			tabEnabled = true;
			return;
		}

		_scrollTarget.addListener(this);
		_scrollTarget.noAutoSelection = true;
		focusTarget = _scrollTarget;
		tabEnabled = false;
		onScroller();
	}


	/**
	 * Returns the available scrolling height of the component.
	 */
	public function get availableHeight(): Number
	{
		return (direction == "horizontal" ? __width : __height) - thumb.height + offsetBottom + offsetTop;
	}


	/** @exclude */
	public function toString(): String
	{
		return "[Scaleform ScrollIndicator " + _name + "]";
	}


	/* PRIVATE FUNCTIONS */

	private function configUI(): Void
	{
		super.configUI();

		if (track == null) {
			track = new Button();
		}

		thumb.focusTarget = this;
		track.focusTarget = this;
		thumb.disabled = _disabled; // track is not a Button instance
		onRelease = function() {}
		useHandCursor = false;

		initSize();
		direction = (_rotation != 0) ? "horizontal" : "vertical";

		if (inspectableScrollTarget != null) {
			var target: Object = _parent[inspectableScrollTarget];
			if (target != null) {
				scrollTarget = target;
			}

			inspectableScrollTarget = null;
		}
	}


	private function draw(): Void
	{
		track._height = (direction=="horizontal") ? __width : __height;
		// Special case for textFields. Explicitly change the scroll properties as it may have changed.
		if (_scrollTarget instanceof TextField) {
			setScrollProperties(_scrollTarget.bottomScroll - _scrollTarget.scroll, 1, _scrollTarget.maxscroll);
		} else {
			updateThumb();
		}
	}


	private function updateThumb(): Void
	{
		// Draw Thumb Size
		if (!thumb.initialized) {	// This ensures we do not try and resize the thumb until it is ready.
			invalidate();
			return;
		}

		if (_disabled) {
			return;
		}

		var per: Number = Math.max(1, maxPosition - minPosition + pageSize);
		var trackHeight: Number = (direction == "horizontal" ? __width : __height) + offsetTop + offsetBottom;
		thumb.height = Math.max(10, pageSize / per * trackHeight);

		// Thumb Position
		var percent: Number = (position - minPosition) / (maxPosition - minPosition);
		var top: Number = -offsetTop;
		var yPos: Number = (percent * availableHeight) + top;

		thumb._y = Math.max(top, Math.min(trackHeight - offsetTop, yPos));
		thumb.visible = !(isNaN(percent) || maxPosition == 0);
	}


	// The scrollTarget TextField has changed its scroll position.
	private function onScroller(): Void
	{
		if (isDragging) {
			return;	// Don't listen for scroll events while the thumb is dragging.
		}

		if (lastVScrollPos == _scrollTarget.scroll) {
			delete(lastVScrollPos);
			return;
		}

        setScrollProperties(_scrollTarget.bottomScroll - _scrollTarget.scroll, 1, _scrollTarget.maxscroll);
		position = _scrollTarget.scroll;

		 // MM BUG : When scrolling a TextField manually, the onScroller event doesn't always get
		 // fired when the field stops scrolling.  Need to use setInterval to manually call onScroller
		 // so we get the most updated scroll values.
		lastVScrollPos = _scrollTarget.scroll;
		if (scrollerIntervalID == undefined) {
			scrollerIntervalID = setInterval(this, "scrollerDelayUpdate", 10);
		}
	}


	private function scrollerDelayUpdate(): Void
	{
		onScroller();
		clearInterval(scrollerIntervalID);
		delete(scrollerIntervalID);
	}
}
