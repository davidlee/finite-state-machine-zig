const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

// Useful stdlib functions
const tokenizeAny = std.mem.tokenizeAny;
const tokenizeSeq = std.mem.tokenizeSequence;
const tokenizeSca = std.mem.tokenizeScalar;
const splitAny = std.mem.splitAny;
const splitSeq = std.mem.splitSequence;
const splitSca = std.mem.splitScalar;
const indexOf = std.mem.indexOfScalar;
const indexOfAny = std.mem.indexOfAny;
const indexOfStr = std.mem.indexOfPosLinear;
const lastIndexOf = std.mem.lastIndexOfScalar;
const lastIndexOfAny = std.mem.lastIndexOfAny;
const lastIndexOfStr = std.mem.lastIndexOfLinear;
const trim = std.mem.trim;
const sliceMin = std.mem.min;
const sliceMax = std.mem.max;

const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;

const print = std.debug.print;
const assert = std.debug.assert;

const sort = std.sort.block;
const asc = std.sort.asc;
const desc = std.sort.desc;
var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
pub const gpa = gpa_impl.allocator();

pub const StateError = error{
    GuardFailed,
    InvalidTransition,
    OnEnterFailed,
    OnExitFailed,
    StateNotFound,
};

const MAX_TRANSITIONS = 20;
const MAX_STATES = 20;

pub const State = struct {
    name: []const u8,
    transitions: std.BoundedArray(*State, MAX_TRANSITIONS) = undefined,
    // context: void,
    guard: ?*const fn (*State) StateError!bool = null,
    on_enter: ?*const fn (*State, *State) StateError!void = null,
    on_exit: ?*const fn (*State, *State) StateError!void = null,

    pub fn index(self: *State) u8 {
        return @intFromEnum(self.tag);
    }

    pub fn enter(self: *State, prev: *State) !void {
        if (self.on_enter) |on_enter|
            try on_enter(self, prev);
    }

    pub fn exit(self: *State, prev: *State) !void {
        if (self.on_exit) |on_exit|
            try on_exit(self, prev);
    }

    pub fn validTarget(self: *State, to: *State) bool {
        for (self.transitions.constSlice()) |t| {
            if (t == to) return true;
        }
        return false;
    }

    pub fn addTransition(self: *State, to: *State) !void {
        try self.transitions.append(to);
    }

    pub fn transitionTo(self: *State, to: *State) !void {
        if (!self.validTarget(to))
            return StateError.InvalidTransition;

        if (!self.guard(self))
            return StateError.GuardFailed;
    }

    pub fn create(name: []const u8) State {
        var state = State{
            .name = name,
        };
        state.transitions = std.BoundedArray(*State, MAX_TRANSITIONS).init(1) catch unreachable;
        return state;
    }
};

pub const FiniteStateMachine = struct {
    states: std.BoundedArray(State, MAX_STATES) = .{},
    current: *State = undefined,
    stack: List(*State) = undefined,

    pub fn define(self: *FiniteStateMachine, state: State) !*State {
        const new_state_ptr = try self.states.addOne();
        new_state_ptr.* = state;
        return new_state_ptr;
    }

    pub fn init(self: *FiniteStateMachine, current: *State) void {
        self.current = current;
        self.stack = List(*State).init(gpa);
    }

    pub fn transitionValid(self: *FiniteStateMachine, to: *State) bool {
        return self.current.validTarget(to);
    }

    pub fn transitionTo(self: *FiniteStateMachine, to: *State) !void {
        if (!self.transitionValid(to))
            return StateError.InvalidTransition;

        if (to.guard) |guard|
            if (!(try guard(to)))
                return StateError.GuardFailed;

        try self.current.exit(to);
        const prev = self.current;
        self.current = to;
        try self.current.enter(prev);
        self.stack.append(self.current) catch unreachable;
    }

    pub fn create(allocator: std.mem.Allocator) *FiniteStateMachine {
        var fsm = allocator.create(FiniteStateMachine) catch unreachable;
        fsm.states = std.BoundedArray(State, MAX_STATES).init(0) catch unreachable;
        fsm.stack = List(*State).init(allocator);
        fsm.current = undefined;
        return fsm;
    }

    pub fn stateNamed(self: *FiniteStateMachine, name: []const u8) !*State {
        for (self.states.constSlice()) |s| {
            if (std.mem.eql(u8, s.name, name)) return s;
        }
        return error.StateNotFound;
    }
};
