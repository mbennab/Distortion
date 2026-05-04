using Godot;
using System;

public partial class Main : Node2D
{
	private TimeAunoteDansHubCentral sceneHUB;
	private TimeOnauteDansPrehistoire scenePrehistoire;
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		// charge et initialise le module HUB
		sceneHUB = GetNode<TimeAunoteDansHubCentral>("TimeAunoteDansHUBCentral");
		sceneHUB.start();
		//charge le module Prehistoire
		scenePrehistoire = GetNode<TimeOnauteDansPrehistoire>("TimeOnauteDansPrehistoire");
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		if(!sceneHUB.started && !sceneHUB.stopped){
			sceneHUB.stop();
			scenePrehistoire.start();
		}
	}
}
