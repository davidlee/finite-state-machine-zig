const FiniteStateMachine = @import("root.zig").FiniteStateMachine;
const State = @import("root.zig").State;
const StateError = @import("root.zig").StateError;
const std = @import("std");
const gpa = std.testing.allocator;
const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;
const expectEqStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;
// const StateNames = [_][]const u8{
//     "Ready",
//     "Set",
//     "Go",
// };

test "fsm" {
    var fsm = FiniteStateMachine.create(gpa);
    defer gpa.destroy(fsm);

    var state_ready = try fsm.define(State.create("Ready"));
    var state_set = try fsm.define(State.create("Set"));
    const state_go = try fsm.define(State.create("Go"));

    try expectEq(3, fsm.states.len);

    try expectEqStrings("Ready", fsm.states.get(0).name);
    try expectEqStrings("Set", fsm.states.get(1).name);
    try expectEqStrings("Go", fsm.states.get(2).name);

    const sl = fsm.states.constSlice();
    try expectEqStrings("Ready", sl[0].name);
    try expectEqStrings("Set", sl[1].name);
    try expectEqStrings("Go", sl[2].name);

    try state_ready.addTransition(state_set);
    try state_set.addTransition(state_go);

    fsm.init(state_ready); // Ready
    try expectEqStrings("Ready", fsm.current.name);
    try fsm.transitionTo(state_set);
    try expectEqStrings("Set", fsm.current.name);
    try expectError(StateError.InvalidTransition, fsm.transitionTo(state_ready));
    try fsm.transitionTo(state_go);
    try expectEqStrings("Go", fsm.current.name);
}

test "fsm with guard" {
    var fsm = FiniteStateMachine.create((gpa));
    defer gpa.destroy(fsm);

    var state_parked = try fsm.define(State.create("Parked"));
    var state_speeding = try fsm.define(State.create("Speeding"));
    var state_ftl = try fsm.define(State.create("FTL"));

    try state_parked.addTransition(state_speeding);
    try state_speeding.addTransition(state_ftl);
    state_speeding.guard = yeah;
    state_ftl.guard = nah;

    fsm.init(state_parked);
    try fsm.transitionTo(state_speeding);
    try expectEqStrings("Speeding", fsm.current.name);
    try expectError(StateError.GuardFailed, fsm.transitionTo(state_ftl));
}

fn yeah(state: *State) StateError!bool {
    _ = state;
    return true;
}

fn nah(state: *State) StateError!bool {
    _ = state;
    return error.GuardFailed;
}
